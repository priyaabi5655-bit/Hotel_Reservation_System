# 🏨 Hotel Reservation & Management System

A web-based PHP & MySQL application designed to streamline hotel reservations, front-desk check-in/checkout operations, and booking management. Built with modern styling powered by **Tailwind CSS** and **Font Awesome** icons.

---

## ✨ Features

### 👤 Customer Portal (`customer_dashboard.php`)

* **Room Search & Filtering:** View available rooms and filter by maximum price per night.


* **Dynamic Cost Calculation:** Automatically computes total cost based on length of stay.


* **Advance & Full Payments:** Support for advance partial payments or full online payments upon booking.


* **Booking Modification:** Change dates and swap room types with real-time price difference & refund/extra charge calculation.


* **Cancellation & Auto-Refund:** Cancel upcoming bookings with automated status tracking.


* **OTP Generation:** Secure 6-digit OTP generated upon booking confirmation for physical check-in verification.



### 🛎️ Receptionist / Front Desk Portal (`receptionist_dashboard.php`)

* **Arrival Management:** Daily arrival tracking with mandatory physical ID match verification and OTP check-in.


* **In-House Guest Management:** Real-time overview of active stays, stay extensions, and additional charge calculation.


* **Checkout & Final Settlement:** Complete checkout processing with automated remaining balance collection and room status updates.


* **No-Show & Arrival Cancellation Handling:** Process no-shows or on-arrival cancellations, automatically releasing rooms back to inventory.



### 🔐 Authentication & System Core (`register.php`, `login.php`, `db.php`)

* **Role-Based Access Control:** Distinct roles for `Customer` and `Receptionist`.


* **Secure Password Hashing:** User passwords securely stored using `password_hash()` (BCrypt).


* **Background Auto-Cleanup (`db.php`):** Background routines (`processExpiredBookingsAndNoShows`) that handle expired un-checked-in bookings while strictly safeguarding checked-in/in-house guests.



---

## 🔑 Demo Logins

| Name | Role (`user`) | Password | Email |
| --- | --- | --- | --- |
| **Merina** | customer | `Merina123` | `Merina123@gmail.com` |
| **Sahasvi** | customer | `Sahasvi@1234` | `Sahasvi2003@gmail.com` |
| **sherin** | customer | `sherin@0987` | `sherin2023@email.com` |
| **Nimal Fernando** | customer | `Nimal@3453` | `nimal.fernando@yahoo.com` |
| **beyah** | customer | `potatofries` | `beyah@gmail.com` |
| **David** | receptionist | `David@1234` | `David@gmail.com` |

---

## 🛠️ Tech Stack

* **Backend:** PHP (8.x)


* **Database:** MySQL / MariaDB (using PDO for secure database interactions)


* **Frontend:** HTML5, JavaScript, Tailwind CSS (via CDN), Font Awesome


* **Timezone Setting:** Asia/Colombo (`+05:30`)



---

## 📂 Project Structure

```
.
├── db.php                     # PDO Database connection & background no-show handler
├── login.php                  # Login page & session initiation
├── register.php               # User registration page (Customer & Receptionist)
├── customer_dashboard.php     # Customer reservation and booking management portal
├── receptionist_dashboard.php # Front-desk operational management dashboard
└── luxury_hotel_db.sql        # Database schema, tables, and Stored Procedures

```

---

## 🚀 Installation & Setup

1. **Clone the Repository**
```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name

```


2. **Web Server Setup**
* Place the project files in your local web server root directory (e.g., `htdocs` for XAMPP or `www` for WampServer).


3. **Database Configuration**
* Open PHPMyAdmin (`http://localhost/phpmyadmin`).
* Create a database named `luxury_hotel_db` (or `hotel_reservation_db`).
* Import `luxury_hotel_db.sql` into your database to setup the schema and stored procedures.


4. **Verify Database Credentials (`db.php`)**
Ensure your database connection details match your environment:
```php
$host = '127.0.0.1';
$user = 'root';
$pass = ''; // Set your MySQL password if applicable

```



5. **Run the Application**
* Open your browser and navigate to: `http://localhost/your-repo-name/login.php`



---

## 📄 License

This project is open-source and available under the [MIT License](https://www.google.com/search?q=LICENSE&utm_source=gemini).
