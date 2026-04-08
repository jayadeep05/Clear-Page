# Clear-Page

Clear Page is an AI-powered book reading and study assistant. It helps users read normal books and activate an AI tutor on-demand to summarize pages and explain text simply.

## Structure
- `backend/`: Spring Boot backend with Spring Data JPA and OpenAI integration.
- `clear_page_app/`: Flutter mobile application.

## 1. Setup Backend
### Prerequisites:
- Java 17
- Maven
- MySQL Server


### Configure OpenAI API:
Open `backend/src/main/resources/application.properties` and replace:
`openai.api.key=YOUR_OPENAI_API_KEY`
with your actual OpenAI API Key.

### Running Backend:
```bash
cd backend
mvnw spring-boot:run
```
The backend will start at `http://localhost:8080`.

## 2. Setup Flutter App
### Prerequisites:
- Flutter SDK
- Android SDK / Android Studio (to generate APK)

### Running the app:
Change directory to the flutter app:
```bash
cd clear_page_app
flutter pub get
flutter run
```

### Building the APK:
To generate the APK for Clear Page:
```bash
flutter build apk --release
```
The APK will be available in `clear_page_app/build/app/outputs/flutter-apk/app-release.apk`.

It's ready to install on your Android device!
