# Caseflow Flutter

## Project Description
Caseflow Flutter is a mobile application designed to streamline case management for users in the legal industry. It offers a user-friendly interface and integrates various features to enhance productivity.

## Features
- User Authentication
- Case Tracking
- Document Management
- Notifications
- Reporting and Analytics

## Project Structure
The project follows a Monorepo-style structure for maximum clarity:

- `/apps`: Main application source code.
  - `/apps/mobile`: Flutter mobile application (formerly `caseflow_flutter`).
  - `/apps/dashboard`: React/Vite web dashboard (formerly `caseflow-dashboard`).
  - `/apps/docs`: Project documentation.
- `/data`: Source legal and act data (BNSS, IPC, CPC, etc.).
- `/releases`: Centralized Android APK and build artifacts.
- `/scripts`: Utility tools for data transformation and database administration.
- `/supabase`: Shared backend configuration and Edge Functions.
- `/temp`: Logs, search results, and temporary scratch files.

## Utility Scripts
Run these from the project root:
- `npm run dashboard:dev`: Start the web dashboard in development mode.
- `npm run mobile:get`: Install Flutter dependencies.
- `npm run upload-bnss`: Sync BNSS data to Supabase.
- `npm run list-admins`: Check database administrator status.

## Installation Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/AMJATH604/caseflow-flutter.git
   ```
2. For mobile development:
   ```bash
   cd caseflow_flutter
   flutter pub get
   ```
3. For dashboard development:
   ```bash
   cd caseflow-dashboard
   npm install
   ```

## Support Information
If you have any questions or need support, please contact the repository owner or create an issue in the repository.

## License Information
This project is licensed under the MIT License. See the `LICENSE` file for more details.