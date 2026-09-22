<?php
// Set consistent timezone matching local server and MySQL
date_default_timezone_set('Asia/Colombo');

$host = '127.0.0.1';
$user = 'root';
$pass = '';
$charset = 'utf8mb4';

$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

// Candidates for database name (prefer active database with valid tables)
$dbCandidates = ['luxury_hotel_db', 'hotel_reservation_db'];
$pdo = null;

foreach ($dbCandidates as $candidateDb) {
    try {
        $dsn = "mysql:host=$host;dbname=$candidateDb;charset=$charset";
        $testPdo = new PDO($dsn, $user, $pass, $options);
        // Verify tables exist and are readable in storage engine
        $testPdo->query("SELECT 1 FROM users LIMIT 1");
        $pdo = $testPdo;
        $db = $candidateDb;
        break;
    } catch (\Throwable $e) {
        // Continue to fallback
        continue;
    }
}

if (!$pdo) {
    // If neither passed the table check, attempt direct connection to primary
    try {
        $dsn = "mysql:host=$host;dbname=hotel_reservation_db;charset=$charset";
        $pdo = new PDO($dsn, $user, $pass, $options);
    } catch (\PDOException $e) {
        die("Database Connection Failed: " . $e->getMessage());
    }
}

/**
 * Auto-process expired reservations and no-shows in the background.
 *
 * CRITICAL BUSINESS RULES:
 * 1. COMPLETELY EXCLUDES and SKIPS any bookings with 'Checked-In' or 'In-House' status.
 *    Guests who have checked in or are currently in-house must NEVER be cancelled or marked expired.
 * 2. EXCLUDES and PROTECTS bookings with valid partial advance payments ('Advance Paid' or 'Paid')
 *    whose stay has not concluded, ensuring advance payments (e.g. LKR 20,000 out of LKR 28,000)
 *    never trigger a 'Past Due' error or auto-cancellation.
 * 3. Only processes un-checked-in 'Confirmed' reservations that have truly passed their due holding window.
 */
function processExpiredBookingsAndNoShows($pdo) {
    if (!$pdo) return;
    try {
        // Query unfulfilled Confirmed bookings past their due window
        // STRICT FILTER: completely excludes Checked-In, In-House, Completed
        $stmt = $pdo->prepare("
            SELECT b.bookingID, b.roomID, b.checkInDate, b.checkOutDate, b.bookingStatus, b.paymentStatus, b.dueTime
            FROM bookings b
            WHERE b.bookingStatus NOT IN ('Checked-In', 'In-House', 'Completed', 'Cancelled', 'No-Show')
              AND b.bookingStatus = 'Confirmed'
              AND b.dueTime IS NOT NULL
              AND b.dueTime < NOW()
        ");
        $stmt->execute();
        $expiredList = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (empty($expiredList)) {
            return;
        }

        foreach ($expiredList as $b) {
            // Hard safety check: completely skip any Checked-In or In-House booking
            if (in_array($b['bookingStatus'], ['Checked-In', 'In-House', 'Completed'])) {
                continue;
            }

            // Check if guest paid advance (partial or full)
            $pStmt = $pdo->prepare("SELECT COALESCE(SUM(amount), 0.00) FROM payments WHERE bookingID = ?");
            $pStmt->execute([$b['bookingID']]);
            $totalPaid = (float)$pStmt->fetchColumn();

            // If a valid partial advance payment was made, do not auto-cancel while stay is active or upcoming
            if ($totalPaid > 0 || $b['paymentStatus'] === 'Advance Paid' || $b['paymentStatus'] === 'Paid') {
                if (strtotime($b['checkOutDate'] . ' 23:59:59') >= time()) {
                    continue;
                }
            }

            // Auto-cancel expired booking and record refund status
            $cancelStmt = $pdo->prepare("
                UPDATE bookings 
                SET bookingStatus = 'Cancelled',
                    refundStatus = IF(paymentStatus = 'Paid' OR paymentStatus = 'Advance Paid', 'No Refund (No-Show)', 'N/A')
                WHERE bookingID = ? 
                  AND bookingStatus NOT IN ('Checked-In', 'In-House', 'Completed')
            ");
            $cancelStmt->execute([$b['bookingID']]);

            // Release room only if no other checked-in guest occupies it
            $roomCheck = $pdo->prepare("
                SELECT COUNT(*) FROM bookings 
                WHERE roomID = ? AND bookingStatus IN ('Checked-In', 'In-House')
            ");
            $roomCheck->execute([$b['roomID']]);
            if ($roomCheck->fetchColumn() == 0) {
                $roomStmt = $pdo->prepare("UPDATE rooms SET status = 'Available' WHERE roomID = ?");
                $roomStmt->execute([$b['roomID']]);
            }
        }
    } catch (PDOException $e) {
        error_log("processExpiredBookingsAndNoShows error: " . $e->getMessage());
    }
}
?>