extends RefCounted
## Firebase-Projekt „lumos-party-game“ – einziges Backend für Konten, Profile und Online-Lobbys.
## Gleiche Werte stehen in web/lumos_bridge.js (FIREBASE_CONFIG, Web-SDK). tools/check_firebase_config.py
## prüft in der CI, dass beide übereinstimmen und dass Google den API-Key akzeptiert.
##
## Der Web-API-Key ist kein Geheimnis (er steht in jeder Firebase-Web-App im Klartext); geschützt wird über
## die Database-Regeln (firebase/database.rules.json) und die autorisierten Domains in Firebase Auth.

const API_KEY := "AIzaSyBpCU5im11sq4YQbs5XPQ26cjs2XTOn4K0"
const AUTH_DOMAIN := "lumos-party-game.firebaseapp.com"
const PROJECT_ID := "lumos-party-game"
const DATABASE_URL := "https://lumos-party-game-default-rtdb.europe-west1.firebasedatabase.app"
const STORAGE_BUCKET := "lumos-party-game.firebasestorage.app"
const MESSAGING_SENDER_ID := "891917891086"
const APP_ID := "1:891917891086:web:e0243215fecaef954e6e5f"
const MEASUREMENT_ID := "G-YWC316WX1W"

const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key="
