# Home Repair Service Booking System

A cross-platform Flutter mobile application for booking home repair services, connecting customers, technicians, and administrators in one system — from booking and quotation to scheduling, payment, and rating.

## Features

The system has three roles, each with its own interface: **Customer**, **Technician**, and **Admin**.

### 🏠 Customer

- Browse service categories and select specific sub-services
- Fill in booking details (address, date, time slot, problem description)
- Upload photos of the problem when booking
- Booked time slots are blocked automatically to prevent double booking
- Track booking status (Pending → Accepted → Quotation Sent → Scheduled → In Progress → Completed)
- View booking history and booking details
- Review technician quotations before payment
- Online payment via ToyyibPay (FPX)
- Download payment receipt as PDF
- Rate and review completed services
- Profile management with profile picture upload
<!-- screenshot -->

### 🔧 Technician

- View personal daily schedule with date navigation
- See assigned booking details (customer, address, service, photos)
- Create quotations after site assessment:
  - Material items selected from the material catalog
  - Labor items, installation fee, and transportation fee
  - Automatic subtotal, 8% tax, discount, and grand total calculation
- Update job status as work progresses
- Receive notifications for newly assigned jobs
<!-- screenshot -->

### 📊 Admin Dashboard

- KPI overview (today's appointments, total users, total technicians, pending orders)
- Today's appointments and pending orders tables
- Quick-access shortcuts to every admin module
<!-- screenshot -->

### 📋 Service Request Management

- Filter bookings by status tabs, service type, date, and keyword search
- View full booking details, including customer, technician, quotation, rating, and photos
- Assign technicians, with matching based on technician specialization
- Update booking status and reschedule with available time-slot checking
<!-- screenshot -->

### 🗓️ Technician Schedule

- Daily schedule of all technicians with date navigation
- Filter appointments by technician
- Add, edit, and deactivate technician accounts
- Manage technician specializations
<!-- screenshot -->

### 👥 User Management

- View all active customers with search
- View user details and total booking count
- Deactivate and reactivate customer accounts
<!-- screenshot -->

### 📦 Material Management

- Maintain the material catalog used in quotations
- Add, edit, and delete materials with unit price and unit type
- Search materials by name
<!-- screenshot -->

### 📈 Business & Performance Reports

- Date filters (Today, Last 30 Days, Last 3/6 Months, This Year, by year/month, custom range)
- KPI cards: total bookings, total revenue, average rating, completion rate
- Booking trends and revenue trends line charts
- Service type distribution pie chart
- Customer rating distribution
- Technician performance ranking (jobs completed, average rating)
<!-- screenshot -->

### 🔔 Push Notifications

- Real-time notifications via Firebase Cloud Messaging
- Notification centre for each role with unread badge count
- Cloud Functions send notifications automatically when:
  - A new booking is created (admin is notified)
  - A technician is assigned (technician is notified)
  - The booking status changes (customer is notified)
  - A new user registers (welcome message)

### 📱 Responsive Design

- Admin pages adapt to phone, tablet, and desktop screen sizes
- Tables switch to card lists on mobile
- Collapsible sidebar navigation

---

## Tech Stack

### Mobile App

| Technology                  | Purpose                       |
| --------------------------- | ----------------------------- |
| Flutter                     | Cross-platform UI framework   |
| Dart                        | Programming language          |
| Provider                    | State management              |
| fl_chart                    | Charts for reports            |
| pdf                         | PDF receipt generation        |
| image_picker / file_picker  | Photo and file upload         |
| flutter_local_notifications | Local notification display    |
| url_launcher / app_links    | Payment redirect and deep link |

### Backend (Firebase)

| Technology                       | Purpose                           |
| -------------------------------- | --------------------------------- |
| Firebase Authentication          | User login and registration       |
| Cloud Firestore                  | NoSQL database                    |
| Firebase Storage                 | Images and file storage           |
| Firebase Cloud Messaging         | Push notifications                |
| Cloud Functions (Node.js)        | Notification triggers             |

### Payment

| Technology        | Purpose                           |
| ----------------- | --------------------------------- |
| ToyyibPay API     | Online payment gateway (FPX)      |

---

## Architecture
Flutter App (Customer / Technician / Admin)
↓
Firebase Authentication ── role-based login
↓
Cloud Firestore
├── users
├── technicians
├── bookings
├── quotations
├── materials
├── ratings
└── notifications
↓ Firestore triggers
Cloud Functions ──→ Firebase Cloud Messaging ──→ Push notifications

Payment: App ──→ ToyyibPay ──→ redirect back to App
