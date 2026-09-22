<?php
session_start();
require 'db.php';

$message = "";
$name = "";
$email = "";
$role = "Customer";

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'Customer';

    if (empty($name) || empty($email) || empty($password)) {
        $message = "Please fill in all required fields.";
    } elseif (strlen($password) < 6) {
        $message = "Password must be at least 6 characters long.";
    } else {
        try {
            // Check if email already exists
            $checkStmt = $pdo->prepare("SELECT userID FROM users WHERE email = ?");
            $checkStmt->execute([$email]);
            
            if ($checkStmt->rowCount() > 0) {
                $message = "Email address already registered. Please use another email or login.";
            } else {
                // Hash the password securely
                $hashedPassword = password_hash($password, PASSWORD_BCRYPT);

                // Insert new user into database
                $stmt = $pdo->prepare("INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)");
                $stmt->execute([$name, $email, $hashedPassword, $role]);

                // Success: Redirect straight to login page
                header("Location: login.php?registered=success");
                exit();
            }
        } catch (PDOException $e) {
            $message = "Registration Error: " . $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Register - Hotel Reservation System</title>
    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Font Awesome Icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="bg-slate-50 min-h-screen flex items-center justify-center p-4 font-sans text-slate-800">

<div class="max-w-md w-full bg-white rounded-2xl shadow-xl border border-slate-100 p-8">
    <!-- Header -->
    <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-14 h-14 bg-emerald-600 text-white rounded-xl shadow-md mb-3 text-2xl">
            <i class="fa-solid fa-user-plus"></i>
        </div>
        <h1 class="text-2xl font-bold text-slate-900">Create Account</h1>
        <p class="text-sm text-slate-500 mt-1">Register for Hotel Reservation System</p>
    </div>

    <!-- Alert -->
    <?php if($message): ?>
        <div class="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm mb-6">
            <i class="fa-solid fa-circle-exclamation flex-shrink-0 text-base"></i>
            <span><?php echo htmlspecialchars($message); ?></span>
        </div>
    <?php endif; ?>

    <!-- Form -->
    <form method="POST" action="register.php" class="space-y-4">
        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="name">Full Name</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-regular fa-user"></i>
                </span>
                <input type="text" id="name" name="name" required placeholder="John Doe" value="<?php echo htmlspecialchars($name); ?>"
                       class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition">
            </div>
        </div>

        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="email">Email Address</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-regular fa-envelope"></i>
                </span>
                <input type="email" id="email" name="email" required placeholder="john@example.com" value="<?php echo htmlspecialchars($email); ?>"
                       class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition">
            </div>
        </div>

        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="password">Password</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-solid fa-lock"></i>
                </span>
                <input type="password" id="password" name="password" required placeholder="••••••••"
                       class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition">
            </div>
            <p class="text-xs text-slate-500 mt-1">Must be at least 6 characters long.</p>
        </div>

        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="role">Role</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-solid fa-id-badge"></i>
                </span>
                <select id="role" name="role"
                        class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition">
                    <option value="Customer" <?php echo ($role === 'Customer') ? 'selected' : ''; ?>>Customer</option>
                    <option value="Receptionist" <?php echo ($role === 'Receptionist') ? 'selected' : ''; ?>>Receptionist</option>
                </select>
            </div>
        </div>

        <button type="submit"
                class="w-full mt-2 py-2.5 px-4 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition duration-150 flex items-center justify-center gap-2">
            <i class="fa-solid fa-user-plus"></i>
            <span>Register</span>
        </button>
    </form>

    <!-- Footer -->
    <div class="mt-8 text-center text-sm text-slate-500 border-t border-slate-100 pt-6">
        Already have an account? 
        <a href="login.php" class="font-semibold text-emerald-600 hover:text-emerald-700 hover:underline">Login here</a>
    </div>
</div>

</body>
</html>