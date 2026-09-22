<?php
session_start();
require 'db.php';

// Handle Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: login.php");
    exit();
}

$error = "";

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = trim($_POST['email']);
    $password = trim($_POST['password']);

    $stmt = $pdo->prepare("CALL sp_LoginUser(?)");
    $stmt->execute([$email]);
    $user = $stmt->fetch();
    $stmt->closeCursor();

    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['userID'] = $user['userID'];
        $_SESSION['name'] = $user['name'];
        $_SESSION['role'] = $user['role'];

        if ($user['role'] == 'Customer') {
            header("Location: customer_dashboard.php");
        } else {
            header("Location: receptionist_dashboard.php");
        }
        exit();
    } else {
        $error = "Invalid Email or Password!";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Hotel Reservation System</title>
    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Font Awesome Icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="bg-slate-50 min-h-screen flex items-center justify-center p-4 font-sans text-slate-800">

<div class="max-w-md w-full bg-white rounded-2xl shadow-xl border border-slate-100 p-8">
    <!-- Header -->
    <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-14 h-14 bg-blue-600 text-white rounded-xl shadow-md mb-3 text-2xl">
            <i class="fa-solid fa-hotel"></i>
        </div>
        <h1 class="text-2xl font-bold text-slate-900">Hotel Reservation</h1>
        <p class="text-sm text-slate-500 mt-1">Sign in to your account</p>
    </div>

    <!-- Error Alert -->
    <?php if($error): ?>
        <div class="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm mb-6">
            <i class="fa-solid fa-circle-exclamation flex-shrink-0 text-base"></i>
            <span><?php echo htmlspecialchars($error); ?></span>
        </div>
    <?php endif; ?>

    <!-- Success message from registration -->
    <?php if(isset($_GET['registered'])): ?>
        <div class="flex items-center gap-3 bg-emerald-50 border border-emerald-200 text-emerald-700 px-4 py-3 rounded-xl text-sm mb-6">
            <i class="fa-solid fa-circle-check flex-shrink-0 text-base"></i>
            <span>Registration successful! Please log in with your credentials.</span>
        </div>
    <?php endif; ?>

    <!-- Form -->
    <form method="POST" action="login.php" class="space-y-5">
        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="email">Email Address</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-regular fa-envelope"></i>
                </span>
                <input type="email" id="email" name="email" required placeholder="name@example.com"
                       class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition">
            </div>
        </div>

        <div>
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-600 mb-1.5" for="password">Password</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-400">
                    <i class="fa-solid fa-lock"></i>
                </span>
                <input type="password" id="password" name="password" required placeholder="••••••••"
                       class="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition">
            </div>
        </div>

        <button type="submit"
                class="w-full py-2.5 px-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg transition duration-150 flex items-center justify-center gap-2">
            <i class="fa-solid fa-arrow-right-to-bracket"></i>
            <span>Login</span>
        </button>
    </form>

    <!-- Footer -->
    <div class="mt-8 text-center text-sm text-slate-500 border-t border-slate-100 pt-6">
        Don't have an account? 
        <a href="register.php" class="font-semibold text-blue-600 hover:text-blue-700 hover:underline">Register here</a>
    </div>
</div>

</body>
</html>