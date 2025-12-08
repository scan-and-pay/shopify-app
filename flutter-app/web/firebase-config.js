// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "FIREBASE_API_KEY_WEB_TEST",
  authDomain: "scan-and-pay-guihzm.firebaseapp.com",
  projectId: "scan-and-pay-guihzm",
  storageBucket: "scan-and-pay-guihzm.firebasestorage.app",
  messagingSenderId: "291088983781",
  appId: "1:291088983781:web:7cfd846d343deb60f4960c"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
export const auth = getAuth(app);
export default app;
