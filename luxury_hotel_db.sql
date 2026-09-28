-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Sep 28, 2026 at 02:32 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `luxury_hotel_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CancelBooking` (IN `p_bookingID` INT, IN `p_refundAmount` DECIMAL(10,2), OUT `p_statusMessage` VARCHAR(100))   BEGIN
    DECLARE v_roomID INT;
    DECLARE v_current_status VARCHAR(30);
 
    SELECT roomID, bookingStatus INTO v_roomID, v_current_status
    FROM bookings
    WHERE bookingID = p_bookingID;
 
    IF v_current_status = 'Confirmed' THEN
        START TRANSACTION;
 
        UPDATE bookings
        SET bookingStatus = 'Cancelled',
            refundStatus = 'Processed',
            extraCharges = p_refundAmount
        WHERE bookingID = p_bookingID;
 
        UPDATE rooms
        SET status = 'Available'
        WHERE roomID = v_roomID;
 
        COMMIT;
        SET p_statusMessage = 'Booking Cancelled Successfully and Refund Processed';
    ELSE
        SET p_statusMessage = 'Booking cannot be cancelled (Invalid status or already processed)';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CheckInGuest` (IN `p_bookingID` INT, IN `p_enteredOTP` VARCHAR(6), OUT `p_statusMessage` VARCHAR(100))   ha: BEGIN
    DECLARE v_roomID INT;
    DECLARE v_bookingStatus VARCHAR(30);
    DECLARE v_storedOTP VARCHAR(6);
 
    SELECT roomID, bookingStatus, otp INTO v_roomID, v_bookingStatus, v_storedOTP
    FROM bookings
    WHERE bookingID = p_bookingID;
 
    IF v_bookingStatus = 'Confirmed' THEN
        IF v_storedOTP != p_enteredOTP THEN
            SET p_statusMessage = 'Check-in failed: Invalid OTP entered.';
            LEAVE ha;
        END IF;
 
        START TRANSACTION;
 
        UPDATE bookings
        SET bookingStatus = 'Checked-In'
        WHERE bookingID = p_bookingID;
 
        UPDATE rooms
        SET status = 'Occupied'
        WHERE roomID = v_roomID;
 
        COMMIT;
        SET p_statusMessage = 'Check-in completed successfully with verified OTP.';
    ELSE
        SET p_statusMessage = 'Check-in failed: Booking is not in Confirmed state';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CheckoutAndGenerateBill` (IN `p_bookingID` INT, IN `p_amountPaid` DECIMAL(10,2), IN `p_extraParam` VARCHAR(255))   BEGIN
    -- Update booking status to Checked-Out and payment status to Paid
    UPDATE bookings
    SET bookingStatus = 'Checked-Out',
        paymentStatus = 'Paid'
    WHERE bookingID = p_bookingID;
 
    -- Insert payment record
    INSERT INTO payments (bookingID, amount)
    VALUES (p_bookingID, p_amountPaid);
 
    -- Update room status back to Available
    UPDATE rooms r
    JOIN bookings b ON r.roomID = b.roomID
    SET r.status = 'Available'
    WHERE b.bookingID = p_bookingID;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CheckoutAndPayment` (IN `p_bookingID` INT, IN `p_finalAmount` DECIMAL(10,2), OUT `p_statusMessage` VARCHAR(100))   BEGIN
    DECLARE v_roomID INT;
 
    SELECT roomID INTO v_roomID
    FROM bookings
    WHERE bookingID = p_bookingID;
 
    START TRANSACTION;
 
    INSERT INTO payments (bookingID, amount)
    VALUES (p_bookingID, p_finalAmount);
 
    UPDATE bookings
    SET bookingStatus = 'Completed', paymentStatus = 'Paid'
    WHERE bookingID = p_bookingID;
 
    UPDATE rooms
    SET status = 'Available'
    WHERE roomID = v_roomID;
 
    COMMIT;
    SET p_statusMessage = 'Checkout and payment completed successfully. Room is now available.';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CreateBooking` (IN `p_userID` INT, IN `p_roomID` INT, IN `p_checkInDate` DATE, IN `p_checkOutDate` DATE, IN `p_otp` VARCHAR(6), IN `p_dueTime` DATETIME, IN `p_agreePolicy` BOOLEAN, IN `p_paidAmount` DECIMAL(10,2), OUT `p_bookingID` INT, OUT `p_statusMessage` VARCHAR(100))   ha: BEGIN
    DECLARE v_room_status VARCHAR(20);
    DECLARE v_room_price DECIMAL(10,2);
    DECLARE v_total_days INT;
    DECLARE v_total_amount DECIMAL(10,2);
    DECLARE v_pay_status VARCHAR(20);

    -- 1. Check policy agreement
    IF p_agreePolicy = FALSE OR p_agreePolicy IS NULL THEN
        SET p_bookingID = 0;
        SET p_statusMessage = 'Booking failed: You must agree to the cancellation and no-show policy.';
        LEAVE ha;
    END IF;

    -- 2. Get room details and check availability
    SELECT status, price INTO v_room_status, v_room_price 
    FROM rooms 
    WHERE roomID = p_roomID;

    IF v_room_status = 'Available' THEN
        SET v_total_days = DATEDIFF(p_checkOutDate, p_checkInDate);
        
        IF v_total_days <= 0 THEN
            SET p_bookingID = 0;
            SET p_statusMessage = 'Booking failed: Check-out date must be after check-in date.';
            LEAVE ha;
        END IF;
        
        -- Calculate exact total expected amount (Per-night price * Total days)
        SET v_total_amount = v_room_price * v_total_days;

        -- 3. Validation Logic:
        -- If paid amount is LESS than total amount -> Advance Paid
        -- If paid amount EQUALS total amount -> Paid
        -- If paid amount is GREATER than total amount -> Block or handle error (As per your requirement: above room price kuduthaa block aaganum)
        IF p_paidAmount > v_total_amount THEN
            SET p_bookingID = 0;
            SET p_statusMessage = CONCAT('Booking failed: Payment cannot exceed total room amount (', v_total_amount, ').');
            LEAVE ha;
        ELSEIF p_paidAmount = v_total_amount THEN
            SET v_pay_status = 'Paid';
        ELSEIF p_paidAmount > 0 THEN
            SET v_pay_status = 'Advance Paid';
        ELSE
            SET p_bookingID = 0;
            SET p_statusMessage = 'Booking failed: Payment amount must be greater than zero.';
            LEAVE ha;
        END IF;

        START TRANSACTION;

        INSERT INTO bookings (userID, roomID, checkInDate, checkOutDate, bookingStatus, paymentStatus, otp, dueTime, agreePolicy, refundStatus)
        VALUES (p_userID, p_roomID, p_checkInDate, p_checkOutDate, 'Confirmed', v_pay_status, p_otp, p_dueTime, p_agreePolicy, 'N/A');

        SET p_bookingID = LAST_INSERT_ID();

        -- Insert the paid amount into payments table so Receptionist can see it!
        INSERT INTO payments (bookingID, amount) 
        VALUES (p_bookingID, p_paidAmount);

        UPDATE rooms 
        SET status = 'Booked' 
        WHERE roomID = p_roomID;

        COMMIT;
        SET p_statusMessage = 'Booking Successful with OTP Generated';
    ELSE
        ROLLBACK;
        SET p_bookingID = 0;
        SET p_statusMessage = 'Room is not available';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ExtendGuestStay` (IN `p_bookingID` INT, IN `p_newCheckOutDate` DATE, IN `p_extraParam` VARCHAR(255))   BEGIN
    UPDATE bookings
    SET checkOutDate = p_newCheckOutDate
    WHERE bookingID = p_bookingID;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ExtendStay` (IN `p_bookingID` INT, IN `p_newCheckOutDate` DATE, IN `p_additionalCharge` DECIMAL(10,2), OUT `p_statusMessage` VARCHAR(100))   BEGIN
    START TRANSACTION;
 
    UPDATE bookings
    SET checkOutDate = p_newCheckOutDate,
        extraCharges = extraCharges + p_additionalCharge
    WHERE bookingID = p_bookingID;
 
    COMMIT;
    SET p_statusMessage = 'Stay extended successfully with extra charges added';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetActiveStays` ()   BEGIN
    SELECT
        b.bookingID,
        b.userID,
        u.name AS customerName,
        b.roomID,
        r.roomType,
        b.checkInDate,
        b.checkOutDate,
        b.bookingStatus,
        b.paymentStatus
    FROM bookings b
    JOIN users u ON b.userID = u.userID
    JOIN rooms r ON b.roomID = r.roomID
    WHERE b.bookingStatus = 'Checked-In';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetAvailableRooms` (IN `p_max_price` DECIMAL(10,2))   BEGIN
    IF p_max_price IS NULL OR p_max_price = 0 THEN
        SELECT roomID, roomType, price, status
        FROM rooms
        WHERE status = 'Available';
    ELSE
        SELECT roomID, roomType, price, status
        FROM rooms
        WHERE status = 'Available' AND price <= p_max_price;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetCancelledOrNoShowBookings` ()   BEGIN
    SELECT b.bookingID, b.userID, u.name AS customerName, b.roomID, r.roomType, b.checkInDate, b.checkOutDate, b.bookingStatus, b.refundStatus
    FROM bookings b
    JOIN users u ON b.userID = u.userID
    JOIN rooms r ON b.roomID = r.roomID
    WHERE b.bookingStatus = 'Cancelled';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetCustomerBookings` (IN `p_userID` INT)   BEGIN
    SELECT 
        b.bookingID,
        r.roomType,
        b.checkInDate,
        b.checkOutDate,
        b.bookingStatus,
        b.paymentStatus,
        b.otp,
        b.dueTime,
        b.extraCharges
    FROM bookings b
    JOIN rooms r ON b.roomID = r.roomID
    WHERE b.userID = p_userID
    ORDER BY b.bookingID DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetTodayArrivals` (IN `p_targetDate` DATE)   BEGIN
    SELECT b.bookingID, b.userID, u.name AS customerName, b.roomID, r.roomType, b.checkInDate, b.checkOutDate, b.bookingStatus
    FROM bookings b
    JOIN users u ON b.userID = u.userID
    JOIN rooms r ON b.roomID = r.roomID
    WHERE b.checkInDate = p_targetDate AND b.bookingStatus = 'Confirmed';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetTodayDepartures` (IN `p_targetDate` DATE)   BEGIN
    SELECT b.bookingID, b.userID, u.name AS customerName, b.roomID, r.roomType, b.checkInDate, b.checkOutDate, b.bookingStatus
    FROM bookings b
    JOIN users u ON b.userID = u.userID
    JOIN rooms r ON b.roomID = r.roomID
    WHERE b.checkOutDate = p_targetDate AND b.bookingStatus = 'Checked-In';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_HandleNoShowOrArrivalCancel` (IN `p_bookingID` INT, IN `p_actionType` VARCHAR(50), OUT `p_msg` VARCHAR(255))   BEGIN
    DECLARE v_roomID INT;
    
    -- Get the room ID associated with the booking
    SELECT roomID INTO v_roomID FROM bookings WHERE bookingID = p_bookingID;
 
    IF p_actionType = 'CancelOnArrival' THEN
        UPDATE bookings 
        SET bookingStatus = 'Cancelled', refundStatus = 'Processed' 
        WHERE bookingID = p_bookingID;
        
        SET p_msg = CONCAT('Success: Booking #', p_bookingID, ' was cancelled on arrival.');
        
    ELSEIF p_actionType = 'NoShow' THEN
        UPDATE bookings 
        SET bookingStatus = 'No-Show' 
        WHERE bookingID = p_bookingID;
        
        SET p_msg = CONCAT('Success: Booking #', p_bookingID, ' marked as No-Show.');
    ELSE
        SET p_msg = 'Error: Invalid action type specified.';
    END IF;
 
    -- Free up the room status back to Available
    IF v_roomID IS NOT NULL THEN
        UPDATE rooms SET status = 'Available' WHERE roomID = v_roomID;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_LoginUser` (IN `p_email` VARCHAR(100))   BEGIN
    SELECT userID, name, email, password, role
    FROM users
    WHERE email = p_email;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ModifyBookingDates` (IN `p_bookingID` INT, IN `p_newRoomID` INT, IN `p_newCheckIn` DATE, IN `p_newCheckOut` DATE, OUT `p_statusMessage` VARCHAR(255))   ha: BEGIN
    DECLARE v_oldRoomID INT;
    DECLARE v_bookingStatus VARCHAR(30);
    DECLARE v_overlap_count INT;
    DECLARE v_newRoomPrice DECIMAL(10,2);
    DECLARE v_totalPaid DECIMAL(10,2);
    DECLARE v_newNights INT;
    DECLARE v_newTotal DECIMAL(10,2);
    DECLARE v_newPaymentStatus VARCHAR(30);

    -- Fetch current booking details
    SELECT roomID, bookingStatus INTO v_oldRoomID, v_bookingStatus
    FROM bookings
    WHERE bookingID = p_bookingID;

    IF v_bookingStatus = 'Confirmed' THEN
        -- Date validation
        IF DATEDIFF(p_newCheckOut, p_newCheckIn) <= 0 THEN
            SET p_statusMessage = 'Modification failed: Invalid date range.';
            LEAVE ha;
        END IF;

        -- Check overlap for new room on target dates (excluding current booking ID)
        SELECT COUNT(*) INTO v_overlap_count
        FROM bookings
        WHERE roomID = p_newRoomID
          AND bookingID != p_bookingID
          AND bookingStatus IN ('Confirmed', 'Checked-In')
          AND (p_newCheckIn < checkOutDate AND p_newCheckOut > checkInDate);

        IF v_overlap_count > 0 THEN
            SET p_statusMessage = 'Modification failed: Target room is unavailable for selected dates.';
            LEAVE ha;
        END IF;

        -- Fetch price of new target room
        SELECT price INTO v_newRoomPrice FROM rooms WHERE roomID = p_newRoomID;

        -- Get total payments made for this booking
        SELECT COALESCE(SUM(amount), 0.00) INTO v_totalPaid FROM payments WHERE bookingID = p_bookingID;

        -- Calculate new total cost
        SET v_newNights = DATEDIFF(p_newCheckOut, p_newCheckIn);
        SET v_newTotal = v_newNights * v_newRoomPrice;

        -- Determine payment status balance
        IF v_totalPaid >= v_newTotal THEN
            SET v_newPaymentStatus = 'Paid';
        ELSE
            SET v_newPaymentStatus = 'Advance Paid';
        END IF;

        START TRANSACTION;

        -- Update booking details with new room and dates
        UPDATE bookings
        SET roomID = p_newRoomID,
            checkInDate = p_newCheckIn,
            checkOutDate = p_newCheckOut,
            paymentStatus = v_newPaymentStatus
        WHERE bookingID = p_bookingID;

        -- Swap room availability if room ID changed
        IF v_oldRoomID != p_newRoomID THEN
            UPDATE rooms SET status = 'Available' WHERE roomID = v_oldRoomID;
            UPDATE rooms SET status = 'Booked' WHERE roomID = p_newRoomID;
        END IF;

        COMMIT;

        SET p_statusMessage = CONCAT('Booking updated! New Total: LKR ', FORMAT(v_newTotal, 2), 
                                     ' | Paid: LKR ', FORMAT(v_totalPaid, 2), 
                                     ' | Balance Due: LKR ', FORMAT(GREATEST(0, v_newTotal - v_totalPaid), 2));
    ELSE
        SET p_statusMessage = 'Modification failed: Only confirmed bookings can be modified.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ProcessNoShows` (OUT `p_statusMessage` VARCHAR(100))   BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_bookingID INT;
    DECLARE v_roomID INT;

    -- Only select unfulfilled Confirmed bookings
    -- STRICT EXCLUSION: Never select Checked-In or In-House bookings
    -- For Advance Paid or Paid bookings, never cancel while stay has not ended
    DECLARE cur CURSOR FOR
        SELECT b.bookingID, b.roomID
        FROM bookings b
        WHERE b.bookingStatus = 'Confirmed'
          AND b.bookingStatus NOT IN ('Checked-In', 'In-House', 'Completed')
          AND (
              (b.paymentStatus NOT IN ('Advance Paid', 'Paid') AND NOW() > b.dueTime)
              OR (b.paymentStatus IN ('Advance Paid', 'Paid') AND NOW() > CONCAT(b.checkOutDate, ' 23:59:59'))
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    START TRANSACTION;
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_bookingID, v_roomID;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        UPDATE bookings
        SET bookingStatus = 'Cancelled', refundStatus = 'No Refund (No-Show)'
        WHERE bookingID = v_bookingID
          AND bookingStatus NOT IN ('Checked-In', 'In-House', 'Completed');

        IF (SELECT COUNT(*) FROM bookings WHERE roomID = v_roomID AND bookingStatus IN ('Checked-In', 'In-House')) = 0 THEN
            UPDATE rooms
            SET status = 'Available'
            WHERE roomID = v_roomID;
        END IF;

    END LOOP;

    CLOSE cur;
    COMMIT;
    SET p_statusMessage = 'No-show processing completed. Expired reservations cancelled and rooms freed.';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_RegenerateOTP` (IN `p_bookingID` INT, IN `p_newOTP` VARCHAR(6), OUT `p_statusMessage` VARCHAR(100))   BEGIN
    START TRANSACTION;
    UPDATE bookings
    SET otp = p_newOTP
    WHERE bookingID = p_bookingID AND bookingStatus = 'Confirmed';
    
    COMMIT;
    SET p_statusMessage = 'New Check-In OTP generated successfully.';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_RegisterUser` (IN `p_name` VARCHAR(100), IN `p_email` VARCHAR(100), IN `p_password` VARCHAR(255), IN `p_role` ENUM('Customer','Receptionist'))   BEGIN
    INSERT INTO users (name, email, password, role)
    VALUES (p_name, p_email, p_password, p_role);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `bookingID` int(11) NOT NULL,
  `userID` int(11) DEFAULT NULL,
  `roomID` int(11) DEFAULT NULL,
  `checkInDate` date DEFAULT NULL,
  `checkOutDate` date DEFAULT NULL,
  `bookingStatus` varchar(30) DEFAULT 'Confirmed',
  `paymentStatus` varchar(30) DEFAULT 'Pending',
  `otp` varchar(6) DEFAULT NULL,
  `refundStatus` varchar(30) DEFAULT 'N/A',
  `dueTime` datetime DEFAULT NULL,
  `agreePolicy` tinyint(1) DEFAULT 1,
  `extraCharges` decimal(10,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `bookings`
--

INSERT INTO `bookings` (`bookingID`, `userID`, `roomID`, `checkInDate`, `checkOutDate`, `bookingStatus`, `paymentStatus`, `otp`, `refundStatus`, `dueTime`, `agreePolicy`, `extraCharges`) VALUES
(1, 1, 1, '2026-09-15', '2026-09-18', 'Cancelled', 'Advance Paid', '621618', 'Processed', '2026-09-15 17:16:38', 1, 1.00),
(2, 1, 2, '2026-09-15', '2026-09-18', 'Checked-Out', 'Paid', '535737', 'N/A', '2026-09-15 17:17:35', 1, 0.00),
(3, 2, 1, '2026-09-15', '2026-09-20', 'Checked-Out', 'Paid', '487446', 'N/A', '2026-09-15 17:20:11', 1, 0.00),
(4, 1, 2, '2026-09-15', '2026-09-18', 'Cancelled', 'Advance Paid', '986329', 'Processed', '2026-09-15 18:58:01', 1, 1.00),
(5, 1, 3, '2026-09-15', '2026-09-20', 'No-Show', 'Advance Paid', '528998', 'N/A', '2026-09-15 19:03:23', 1, 0.00),
(6, 2, 1, '2026-09-16', '2026-09-23', 'Checked-Out', 'Paid', '398752', 'N/A', '2026-09-16 10:41:30', 1, 0.00),
(7, 2, 2, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '881971', 'Processed', '2026-09-17 04:39:26', 1, 2.00),
(8, 2, 1, '2026-09-17', '2026-09-19', 'Cancelled', 'Advance Paid', '570096', 'Processed', '2026-09-17 04:57:47', 1, 2.00),
(9, 1, 1, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '527801', 'Processed', '2026-09-17 05:13:33', 1, 1.00),
(10, 1, 1, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '655396', 'Processed', '2026-09-17 08:10:29', 1, 1.00),
(11, 1, 4, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '154957', 'Processed', '2026-09-17 08:11:05', 1, 1.00),
(12, 1, 5, '2026-09-17', '2026-09-19', 'Cancelled', 'Advance Paid', '659599', 'Processed', '2026-09-17 08:11:32', 1, 1.00),
(13, 1, 1, '2026-09-17', '2026-09-20', 'Cancelled', 'Advance Paid', '346487', 'Processed', '2026-09-17 10:23:27', 1, 1.00),
(14, 1, 2, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '169498', 'Processed', '2026-09-17 10:24:05', 1, 1.00),
(15, 2, 1, '2026-09-17', '2026-09-18', 'Completed', 'Paid', '780905', 'N/A', '2026-09-17 10:42:12', 1, 0.00),
(16, 2, 1, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '590935', 'No Refund (No-Show)', '2026-09-17 20:00:00', 1, 0.00),
(17, 2, 1, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '791992', 'No Refund (No-Show)', '2026-09-17 19:24:45', 1, 0.00),
(18, 2, 1, '2026-09-17', '2026-09-18', 'Cancelled', 'Paid', '666251', 'No Refund (No-Show)', '2026-09-17 19:33:30', 1, 0.00),
(19, 2, 1, '2026-09-17', '2026-09-18', 'No-Show', 'Advance Paid', '441661', 'N/A', '2026-09-18 03:19:45', 1, 0.00),
(20, 2, 1, '2026-09-17', '2026-09-19', 'Completed', 'Paid', '890484', 'N/A', '2026-09-18 23:59:59', 1, 0.00),
(21, 1, 1, '2026-09-17', '2026-09-21', 'Completed', 'Paid', '853646', 'N/A', '2026-09-18 03:57:03', 1, 0.00),
(22, 1, 2, '2026-09-17', '2026-09-18', 'Completed', 'Paid', '527316', 'N/A', '2026-09-18 04:05:33', 1, 0.00),
(23, 1, 2, '2026-09-17', '2026-09-18', 'Completed', 'Paid', '228197', 'N/A', '2026-09-18 04:18:00', 1, 0.00),
(24, 1, 1, '2026-09-17', '2026-09-19', 'Completed', 'Paid', '495128', 'N/A', '2026-09-18 23:59:59', 1, 0.00),
(25, 5, 1, '2026-09-18', '2026-09-21', 'Completed', 'Paid', '399342', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(26, 5, 2, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '749492', 'Processed', '2026-09-19 23:59:59', 1, 5.00),
(27, 1, 1, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '917417', 'Processed', '2026-09-19 23:59:59', 1, 1.00),
(28, 1, 1, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '791173', 'Processed', '2026-09-19 23:59:59', 1, 0.00),
(29, 2, 2, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '623524', 'Processed', '2026-09-19 23:59:59', 1, 2.00),
(30, 2, 2, '2026-09-18', '2026-09-20', 'Cancelled', 'Paid', '829121', 'Processed', '2026-09-19 23:59:59', 1, 2.00),
(31, 2, 3, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '330855', 'Processed', '2026-09-19 23:59:59', 1, 2.00),
(32, 2, 4, '2026-09-18', '2026-09-19', 'Cancelled', 'Advance Paid', '749064', 'Processed', '2026-09-19 23:59:59', 1, 2.00),
(33, 2, 5, '2026-09-18', '2026-09-20', 'Cancelled', 'Paid', '539216', 'Processed', '2026-09-20 23:59:59', 1, 2.00),
(34, 5, 2, '2026-09-18', '2026-09-20', 'Cancelled', 'Paid', '556290', 'Processed', '2026-09-19 23:59:59', 1, 5.00),
(35, 5, 2, '2026-09-18', '2026-09-19', 'No-Show', 'Paid', '769462', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(36, 5, 3, '2026-09-18', '2026-09-19', 'Completed', 'Paid', '201398', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(37, 5, 4, '2026-09-18', '2026-09-20', 'Completed', 'Paid', '892312', 'N/A', '2026-09-20 23:59:59', 1, 0.00),
(38, 1, 4, '2026-09-18', '2026-09-20', 'Completed', 'Paid', '438922', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(39, 1, 5, '2026-09-18', '2026-09-23', 'Completed', 'Paid', '105438', 'N/A', '2026-09-21 23:59:59', 1, 0.00),
(40, 5, 1, '2026-09-18', '2026-09-20', 'Cancelled', 'Advance Paid', '152461', 'Processed', '2026-09-20 23:59:59', 1, 0.00),
(41, 5, 1, '2026-09-18', '2026-09-20', 'Cancelled', 'Advance Paid', '629564', 'Processed', '2026-09-20 23:59:59', 1, 0.00),
(42, 1, 1, '2026-09-18', '2026-09-19', 'Cancelled', 'Paid', '637238', 'Processed', '2026-09-19 23:59:59', 1, 1.00),
(43, 1, 1, '2026-09-18', '2026-09-22', 'Cancelled', 'Paid', '238914', 'Processed', '2026-09-20 23:59:59', 1, 0.00),
(44, 1, 2, '2026-09-18', '2026-09-19', 'No-Show', 'Advance Paid', '773831', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(45, 1, 3, '2026-09-18', '2026-09-19', 'Completed', 'Paid', '970093', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(46, 1, 4, '2026-09-18', '2026-09-21', 'Completed', 'Paid', '593316', 'N/A', '2026-09-20 23:59:59', 1, 0.00),
(47, 1, 1, '2026-09-18', '2026-09-21', 'Completed', 'Paid', '814673', 'N/A', '2026-09-19 23:59:59', 1, 0.00),
(48, 1, 1, '2026-09-18', '2026-09-20', 'Checked-In', 'Advance Paid', '479032', 'N/A', '2026-09-20 23:59:59', 1, 0.00),
(49, 7, 4, '2026-09-18', '2026-09-20', 'Checked-In', 'Paid', '820548', 'N/A', '2026-09-20 23:59:59', 1, 0.00),
(50, 7, 2, '2026-09-20', '2026-09-23', 'Confirmed', 'Paid', '413481', 'N/A', '2026-09-23 23:59:59', 1, 0.00),
(51, 9, 3, '2026-09-18', '2026-09-20', 'Completed', 'Paid', '551265', 'N/A', '2026-09-20 23:59:59', 1, 0.00),
(52, 10, 5, '2026-09-20', '2026-09-22', 'Confirmed', 'Paid', '151924', 'N/A', '2026-09-22 23:59:59', 1, 0.00),
(53, 10, 6, '2026-09-18', '2026-09-22', 'Cancelled', 'Paid', '954377', 'Processed', '2026-09-22 23:59:59', 1, 10.00),
(54, 9, 3, '2026-09-22', '2026-09-24', 'Cancelled', 'Paid', '277404', 'Processed', '2026-09-24 23:59:59', 1, 9.00),
(55, 9, 3, '2026-09-27', '2026-09-28', 'Confirmed', 'Paid', '976692', 'N/A', '2026-09-28 23:59:59', 1, 0.00),
(56, 9, 10, '2026-09-27', '2026-09-28', 'Cancelled', 'Paid', '413098', 'Processed', '2026-09-28 23:59:59', 1, 9.00),
(57, 9, 10, '2026-09-27', '2026-09-28', 'Confirmed', 'Paid', '818754', 'N/A', '2026-09-28 23:59:59', 1, 0.00),
(58, 11, 8, '2026-09-25', '2026-09-28', 'Confirmed', 'Paid', '348850', 'N/A', '2026-09-28 23:59:59', 1, 0.00),
(59, 11, 6, '2026-09-29', '2026-09-30', 'Confirmed', 'Advance Paid', '264259', 'N/A', '2026-09-30 23:59:59', 1, 0.00);

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `paymentID` int(11) NOT NULL,
  `bookingID` int(11) DEFAULT NULL,
  `amount` decimal(10,2) DEFAULT NULL,
  `paymentDate` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`paymentID`, `bookingID`, `amount`, `paymentDate`) VALUES
(1, 1, 10000.00, '2026-09-15 13:16:38'),
(2, 2, 20000.00, '2026-09-15 13:17:35'),
(3, 3, 10000.00, '2026-09-15 13:20:11'),
(4, 2, 50000.00, '2026-09-15 13:24:52'),
(5, 4, 20000.00, '2026-09-15 14:58:01'),
(6, 5, 40000.00, '2026-09-15 15:03:23'),
(7, 3, 5000.00, '2026-09-15 15:05:20'),
(8, 6, 15000.00, '2026-09-16 06:41:30'),
(9, 6, 50000.00, '2026-09-16 06:43:45'),
(10, 7, 30000.00, '2026-09-17 00:39:26'),
(11, 8, 16000.00, '2026-09-17 00:57:47'),
(12, 9, 20000.00, '2026-09-17 01:13:33'),
(13, 10, 15000.00, '2026-09-17 04:10:29'),
(14, 11, 20000.00, '2026-09-17 04:11:05'),
(15, 12, 10000.00, '2026-09-17 04:11:32'),
(16, 13, 40000.00, '2026-09-17 06:23:27'),
(17, 14, 28000.00, '2026-09-17 06:24:05'),
(18, 15, 10000.00, '2026-09-17 06:42:12'),
(19, 15, 5000.00, '2026-09-17 06:50:05'),
(20, 16, 15000.00, '2026-09-17 14:51:47'),
(21, 17, 15000.00, '2026-09-17 15:24:45'),
(22, 18, 15000.00, '2026-09-17 15:33:30'),
(23, 19, 10000.00, '2026-09-17 15:49:45'),
(24, 20, 15000.00, '2026-09-17 15:53:44'),
(25, 20, 15000.00, '2026-09-17 16:23:18'),
(26, 21, 15000.00, '2026-09-17 16:27:03'),
(27, 22, 28000.00, '2026-09-17 16:35:33'),
(28, 22, 0.00, '2026-09-17 16:36:34'),
(29, 23, 20000.00, '2026-09-17 16:48:00'),
(30, 23, 8000.00, '2026-09-17 17:10:10'),
(31, 21, 45000.00, '2026-09-17 17:10:14'),
(32, 24, 10000.00, '2026-09-17 17:11:29'),
(33, 24, 20000.00, '2026-09-17 17:21:00'),
(34, 24, 20000.00, '2026-09-17 18:02:43'),
(35, 25, 15000.00, '2026-09-18 04:21:19'),
(36, 25, 30000.00, '2026-09-18 04:25:10'),
(37, 26, 28000.00, '2026-09-18 04:36:20'),
(38, 27, 15000.00, '2026-09-18 07:11:31'),
(39, 28, 15000.00, '2026-09-18 07:12:25'),
(40, 29, 28000.00, '2026-09-18 07:15:25'),
(41, 30, 28000.00, '2026-09-18 07:16:19'),
(42, 31, 45000.00, '2026-09-18 07:17:44'),
(43, 32, 10000.00, '2026-09-18 07:18:19'),
(44, 33, 30000.00, '2026-09-18 07:18:54'),
(45, 34, 28000.00, '2026-09-18 07:26:09'),
(46, 35, 28000.00, '2026-09-18 07:28:07'),
(47, 36, 40000.00, '2026-09-18 07:28:34'),
(48, 37, 30000.00, '2026-09-18 07:29:10'),
(49, 37, 0.00, '2026-09-18 07:31:25'),
(50, 38, 10000.00, '2026-09-18 07:46:33'),
(51, 39, 45000.00, '2026-09-18 07:47:00'),
(52, 40, 20000.00, '2026-09-18 07:55:46'),
(53, 41, 10000.00, '2026-09-18 08:01:37'),
(54, 36, 5000.00, '2026-09-18 08:09:23'),
(55, 38, 20000.00, '2026-09-18 08:17:49'),
(56, 39, 30000.00, '2026-09-18 08:20:07'),
(57, 42, 15000.00, '2026-09-18 12:16:58'),
(58, 43, 30000.00, '2026-09-18 12:18:40'),
(59, 44, 20000.00, '2026-09-18 12:22:42'),
(60, 45, 45000.00, '2026-09-18 12:23:58'),
(61, 46, 30000.00, '2026-09-18 12:24:56'),
(62, 45, 0.00, '2026-09-18 12:56:28'),
(63, 46, 15000.00, '2026-09-18 13:04:10'),
(64, 47, 15000.00, '2026-09-18 13:06:17'),
(65, 47, 30000.00, '2026-09-18 13:09:04'),
(66, 48, 10000.00, '2026-09-18 13:11:38'),
(67, 49, 30000.00, '2026-09-18 14:14:41'),
(68, 50, 84000.00, '2026-09-18 14:15:35'),
(69, 51, 90000.00, '2026-09-18 15:00:05'),
(70, 52, 30000.00, '2026-09-18 15:17:36'),
(71, 53, 112000.00, '2026-09-18 15:18:11'),
(72, 51, 0.00, '2026-09-18 15:24:57'),
(73, 54, 90000.00, '2026-09-22 07:57:26'),
(74, 55, 45000.00, '2026-09-22 08:29:54'),
(75, 56, 15000.00, '2026-09-22 08:33:49'),
(76, 57, 15000.00, '2026-09-22 08:42:21'),
(77, 58, 135000.00, '2026-09-22 15:29:06'),
(78, 59, 2800.00, '2026-09-22 15:31:05');

-- --------------------------------------------------------

--
-- Table structure for table `rooms`
--

CREATE TABLE `rooms` (
  `roomID` int(11) NOT NULL,
  `roomType` varchar(50) DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'Available'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `rooms`
--

INSERT INTO `rooms` (`roomID`, `roomType`, `price`, `status`) VALUES
(1, 'Standard Single Room', 15000.00, 'Occupied'),
(2, 'Deluxe Double Suite', 28000.00, 'Booked'),
(3, 'Executive Luxury Room', 45000.00, 'Booked'),
(4, 'Standard Single Room', 15000.00, 'Occupied'),
(5, 'Standard Single Room', 15000.00, 'Booked'),
(6, 'Deluxe Double Suite', 28000.00, 'Booked'),
(7, 'Deluxe Double Suite', 28000.00, 'Available'),
(8, 'Executive Luxury Room', 45000.00, 'Booked'),
(9, 'Executive Luxury Room', 45000.00, 'Available'),
(10, 'Standard Single Room', 15000.00, 'Booked');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `userID` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('Customer','Receptionist') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`userID`, `name`, `email`, `password`, `role`) VALUES
(1, 'John Smith', 'john.smith@gmail.com', '$2y$10$RIg9SGZJ/Ml2PiG6uOgqsOntc/lJD6yrfG4W1uz3SMh6ZA9Br2/mS', 'Customer'),
(2, 'Sarah Jenkins', 'sarah.reception@hotel.com', '$2y$10$wUxKNPaCihsEweMMZglszuvjVukRMUws8lx6QZ1Teyc9I8eOM.DT6', 'Customer'),
(3, 'John Doe', 'john.doe@gmail.com', '$2y$10$GB8Vno6oz/3vQPQyviu0ounLG15CFocQX5TR7oSi6hdBDGTv2Js02', 'Receptionist'),
(4, 'John Tail', 'john.tail@gmail.com', '$2y$10$g90MhzoG5y3lAeQqcvCdWOlttRNss1qZ2isZobc/NHryThLeCS8Bi', 'Receptionist'),
(5, 'Rahul Sharma', 'rahul.customer@gmail.com', '$2y$10$KNJ513lNpdKGuf4sAk/nmuEvswZE5YZso6Doh001wGzaPOlzw8DDy', 'Customer'),
(6, 'Ramya Fernando', 'ramya.reception@gmail.com', '$2y$10$Xnk2qy06jBma9f7SQdjfyuBTYgRVnyKK0vnrF.XwyFTelzU9bF.tK', 'Receptionist'),
(7, 'beyah', 'beyah@gmail.com', '$2y$10$N/Kyvw7BxJCxk7cx5pvOXu8PUIyBCSbdigJxGaxyNtKYKwKf1s7GS', 'Customer'),
(8, 'David Cooper', 'David@gmail.com', '$2y$10$BCJwwN6dDdwOM62RoLu3Be4uDOjHKWVYdvrGf/p01dLlAs9IWwL.2', 'Receptionist'),
(9, 'Merina', 'Merina123@gmail.com', '$2y$10$gOrzl6RVbQ89bk7zNfYy6.KsV/pYQnv7ok8KMr.zRvUF7Jq2SLaFe', 'Customer'),
(10, 'Sahasvi', 'Sahasvi2003@gmail.com', '$2y$10$EFPs2Dig/VkDWPlM/5d55.v9N4K4Fo5S6.l54iNgl0S2a7YWsRjle', 'Customer'),
(11, 'hinaza umarali', 'hina@gmail.com', '$2y$10$bsVArqhC6pbyw02C3U9dL.qpav42WJdpMcw1HADkmExTTEVVqGyyi', 'Customer');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`bookingID`),
  ADD KEY `userID` (`userID`),
  ADD KEY `roomID` (`roomID`),
  ADD KEY `idx_checkin` (`checkInDate`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`paymentID`),
  ADD KEY `bookingID` (`bookingID`);

--
-- Indexes for table `rooms`
--
ALTER TABLE `rooms`
  ADD PRIMARY KEY (`roomID`),
  ADD KEY `idx_room_status` (`status`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`userID`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `bookingID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=60;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `paymentID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=79;

--
-- AUTO_INCREMENT for table `rooms`
--
ALTER TABLE `rooms`
  MODIFY `roomID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `userID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`userID`) REFERENCES `users` (`userID`),
  ADD CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`roomID`) REFERENCES `rooms` (`roomID`);

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`bookingID`) REFERENCES `bookings` (`bookingID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
