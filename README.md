# 📱 Innoven Support - Flutter App

A high-performance, cross-platform mobile application designed to streamline field operations and enhance customer experience. This app serves as the primary tool for field engineers to manage their tasks and for customers to track their service requests in real-time.

---

## 🏗️ Tech Stack

| Layer                | Technology                   |
| -------------------- | ---------------------------- |
| **Framework**        | Flutter (Dart)               |
| **State Management** | Provider                     |
| **Navigation**       | go_router                    |
| **Networking**       | Dio / Http                   |
| **Authentication**   | Token-based (Secure Storage) |
| **UI Components**    | Custom Material 3 Design     |

---

## 🚀 Key Features

### 1. 👷 Engineer Workspace

- **Unified Dashboard:** A single, consolidated view of all assigned Installations and Service/Repair jobs.
- **Workflow Automation:** Step-by-step task completion: Visiting -> Barcode Scan -> OTP Verification -> Proof Upload.
- **On-Site Proof:** Seamlessly capture and upload photo evidence of completed work directly to the backend.

### 2. 👥 Customer Portal

- **Real-Time Tracking:** Watch the progress of your ticket from assignment to completion.
- **Service Verification:** Receive and verify OTPs to ensure jobs are completed to your satisfaction.
- **Visual Receipts:** View the uploaded proof of service images once a job is finished.

### 3. 🛡️ Secure Operations

- **Role-Based Access:** Dedicated interfaces for Engineers and Customers.
- **OTP-Verified Completion:** Ensures that no job is marked as "Done" without explicit customer verification.
- **Reliable Sync:** Real-time synchronization with the backend API for accurate status updates.

---

## 📱 Screen Overview

- **Login Screen:** Secure entry with credentials and role detection.
- **Engineer Dashboard:** Categorized job views (Pending, In Progress, Done) with dynamic action buttons.
- **Customer Dashboard:** A transparent view of active and historical service requests.
- **Proof Upload:** Integrated camera functionality for high-quality service evidence.

---

## 🚀 Getting Started

1. **Install Flutter:**
   Ensure you have the Flutter SDK installed and configured on your machine.
2. **Clone & Dependencies:**
   ```bash
   cd hrm_mobile_app
   flutter pub get
   ```
3. **Configure API:**
   Set the `baseUrl` in `lib/core/constants/app_constants.dart` to point to your Innoven Support Backend.
4. **Run Application:**
   ```bash
   flutter run
   ```

---

&copy; 2026 Innoven Support System. All Rights Reserved.
