
//  Broches
const int pinENA = 9;
const int pinIN1 = 10;
const int pinIN2 = 11;

const int pinACS712   = A0;
const int pinEncodeur = 2;

const int ledVerte  = 22;   // NORMAL
const int ledOrange = 24;   // DEGRADE
const int ledRouge  = 26;   // DEFAUT

//  Capteurs
const float sensibilite = 100.0;   // ACS712 20 A : 100 mV/A
const float vcc = 5.0;
float zeroCapteurTension = 2.5;    // recalcule au demarrage

const float ratioReduction = 43.8;
const float pprAxeMoteur   = 16.0;
// Interruption sur CHANGE = 2 fronts par impulsion
const float totalFrontsParTourSortie = pprAxeMoteur * ratioReduction * 2.0; // 1401.6

// ============================================================
//  Protocole UART (identique a package_constants.vhd)
// ============================================================
const byte DEBUT = 0xAA;   // UART_START
const byte FIN   = 0x55;   // UART_STOP
const byte ETAT_NORMAL  = 0x01;
const byte ETAT_DEGRADE = 0x02;
const byte ETAT_DEFAUT  = 0x03;

// ============================================================
//  Securite et phase de demarrage
// ============================================================
const float seuilCourantDefaut_mA = 2000.0;
bool securiteDeclenchee = false;

// Le FPGA classe FAULT tant que rpm <= 50 : sans phase de lancement,
// le moteur ne pourrait jamais demarrer (vitesse 0 -> DEFAUT -> arret).
const unsigned long DEMARRAGE_MS = 2000;
unsigned long debutDemarrage = 0;
bool enDemarrage = false;

// ============================================================
//  Encodeur
// ============================================================
volatile unsigned long compteurFronts = 0;
unsigned long dernierCompteur  = 0;
unsigned long dernierTempsRPM  = 0;
const unsigned long intervalleRPM = 100;   // 100 ms -> 10 Hz

// ============================================================
//  Mesures et commande
// ============================================================
float vitesseRPM       = 0.0;
float courantMoteur_mA = 0.0;
int   consignePWM      = 0;    // PWM calcule par la regulation
float cibleRPM         = 0.0;  // vitesse demandee au clavier (tr/min)
float pwmRegule        = 0.0;  // PWM en flottant pour la regulation
const float KP         = 0.15; // gain : correction PWM par tr/min d'ecart
const float VITESSE_MAX = 300.0;

// ============================================================
//  Etat recu du FPGA
// ============================================================
byte etatFPGA       = 0x00;    // 0 = aucun etat recu
byte etapeReception = 0;
byte etatRecu       = 0;
bool nouvelleTrameFPGA = false;

unsigned long dernierClign = 0;
bool etatClign = false;

// ============================================================
//  Interruption encodeur
// ============================================================
void lectureEncodeur() {
  compteurFronts++;
}

// ============================================================
//  Commande moteur (bas niveau)
// ============================================================
void appliquerPWM(int valeur) {
  valeur = constrain(valeur, 0, 255);
  digitalWrite(pinIN1, HIGH);      // sens de rotation fixe
  digitalWrite(pinIN2, LOW);
  analogWrite(pinENA, valeur);
}

void couperMoteur() {
  analogWrite(pinENA, 0);
  digitalWrite(pinIN1, LOW);
  digitalWrite(pinIN2, LOW);
}

// ============================================================
//  Reaction : l'Arduino traduit le verdict du FPGA en PWM
// ============================================================
void reagirSelonEtat(byte etat) {
  // Pendant le lancement, on ignore le FPGA pour que le moteur
  // prenne de la vitesse et sorte du FAULT initial.
  if (enDemarrage) {
    appliquerPWM(consignePWM);
    return;
  }
  if (etat == ETAT_NORMAL)       appliquerPWM(consignePWM);
  else if (etat == ETAT_DEGRADE) appliquerPWM(consignePWM / 2);
  else if (etat == ETAT_DEFAUT)  couperMoteur();
  else                           appliquerPWM(consignePWM);  // aucun etat recu
}

// ============================================================
//  LEDs (rouge clignotante en DEFAUT)
// ============================================================
void mettreAJourLEDs(byte etat) {
  digitalWrite(ledVerte,  etat == ETAT_NORMAL);
  digitalWrite(ledOrange, etat == ETAT_DEGRADE);
  if (etat == ETAT_DEFAUT) {
    if (millis() - dernierClign >= 200) {
      etatClign = !etatClign;
      dernierClign = millis();
    }
    digitalWrite(ledRouge, etatClign);
  } else {
    digitalWrite(ledRouge, LOW);
  }
}

// ============================================================
//  Nom lisible de l'etat
// ============================================================
const char* texteEtat(byte etat) {
  if (etat == ETAT_NORMAL)  return "NORMAL";
  if (etat == ETAT_DEGRADE) return "DEGRADE";
  if (etat == ETAT_DEFAUT)  return "DEFAUT";
  return "INCONNU";
}

// ============================================================
//  Commandes du moniteur serie
// ============================================================
void lireCommandeSerie() {
  if (Serial.available() == 0) return;
  char c = Serial.peek();

  if (c == 's' || c == 'S') {
    Serial.read();
    consignePWM = 0;
    cibleRPM = 0.0;
    pwmRegule = 0.0;
    enDemarrage = false;
    couperMoteur();
    Serial.println("# Moteur arrete.");
  }
  else if (c == 'r' || c == 'R') {
    Serial.read();
    securiteDeclenchee = false;
    Serial.println("# Securite rearmee. Entrez une puissance (0-255).");
  }
  else if (c >= '0' && c <= '9') {
int valeur = Serial.parseInt();
    cibleRPM = constrain(valeur, 0, (int)VITESSE_MAX);
    securiteDeclenchee = false;
    if (cibleRPM > 0) {             // lance la phase de demarrage
      enDemarrage = true;
      debutDemarrage = millis();
      if (pwmRegule < 100.0) pwmRegule = 100.0;  // amorce le demarrage
    }
    Serial.print("# Vitesse cible : ");
    Serial.print(cibleRPM, 0);
    Serial.println(" tr/min");
  }
  else {
    Serial.read();
  }
}

// ============================================================
//  Lecture du courant (mA)
// ============================================================
float lireCourant_mA() {
  long somme = 0;
  const int nbEchantillons = 50;
  for (int i = 0; i < nbEchantillons; i++) {
    somme += analogRead(pinACS712);
    delayMicroseconds(200);
  }
  float moyenne = (float)somme / nbEchantillons;
  float tension = (moyenne * vcc) / 1023.0;
  float courant_A = (tension - zeroCapteurTension) / (sensibilite / 1000.0);
  float mA = fabs(courant_A) * 1000.0;
  if (mA < 100.0) mA = 0.0;   // supprime le bruit residuel autour de 0
  return mA;
}

// ============================================================
//  Envoi Arduino -> FPGA (7 octets, poids fort en premier)
// ============================================================
void envoyerMesuresFPGA(uint16_t rpm, uint16_t courant) {
  byte rpmH = highByte(rpm);
  byte rpmL = lowByte(rpm);
  byte curH = highByte(courant);
  byte curL = lowByte(courant);
  byte checksum = rpmH ^ rpmL ^ curH ^ curL;

  Serial1.write(DEBUT);
  Serial1.write(rpmH);
  Serial1.write(rpmL);
  Serial1.write(curH);
  Serial1.write(curL);
  Serial1.write(checksum);
  Serial1.write(FIN);
}

// ============================================================
//  Reception FPGA -> Arduino : AA | ETAT | 55
// ============================================================
void lireReponseFPGA() {
  while (Serial1.available() > 0) {
    byte b = Serial1.read();

    if (etapeReception == 0) {
      if (b == DEBUT) etapeReception = 1;          // marqueur de debut
    }
    else if (etapeReception == 1) {
      if (b == ETAT_NORMAL || b == ETAT_DEGRADE || b == ETAT_DEFAUT) {
        etatRecu = b;
        etapeReception = 2;
      } else if (b == DEBUT) {
        etapeReception = 1;                        // resynchronisation
      } else {
        etapeReception = 0;
      }
    }
    else if (etapeReception == 2) {
      if (b == FIN) {                              // trame complete valide
        etatFPGA = etatRecu;
        nouvelleTrameFPGA = true;
      }
      etapeReception = 0;
    }
  }
}

// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);    // moniteur USB
  Serial1.begin(115200);   // liaison FPGA (TX1 = D18, RX1 = D19)

  pinMode(pinENA, OUTPUT);
  pinMode(pinIN1, OUTPUT);
  pinMode(pinIN2, OUTPUT);
  pinMode(pinEncodeur, INPUT_PULLUP);
  pinMode(ledVerte,  OUTPUT);
  pinMode(ledOrange, OUTPUT);
  pinMode(ledRouge,  OUTPUT);

  digitalWrite(ledVerte,  LOW);
  digitalWrite(ledOrange, LOW);
  digitalWrite(ledRouge,  LOW);

  couperMoteur();
  delay(500);

  // Etalonnage du zero de l'ACS712, moteur a l'arret
  Serial.println("# Etalonnage de l'ACS712... Ne pas lancer le moteur.");
  long somme = 0;
  const int echantillons = 30;
  for (int i = 0; i < echantillons; i++) {
    somme += analogRead(pinACS712);
    delay(2);
  }
  zeroCapteurTension = ((float)somme / echantillons * vcc) / 1023.0;
  Serial.print("# Tension de repos : ");
  Serial.print(zeroCapteurTension, 3);
  Serial.println(" V");
  if (zeroCapteurTension < 2.40 || zeroCapteurTension > 2.60)
    Serial.println("# ATTENTION : tension de repos anormale, verifier l'ACS712.");

  Serial.println("# Commandes : 0-255 = PWM | s = stop | r = rearmer");

  attachInterrupt(digitalPinToInterrupt(pinEncodeur), lectureEncodeur, CHANGE);
  dernierTempsRPM = millis();
}

// ============================================================
//  LOOP
// ============================================================
void loop() {
  lireReponseFPGA();
  lireCommandeSerie();

  // Fin de la phase de demarrage
  if (enDemarrage && (millis() - debutDemarrage >= DEMARRAGE_MS)) {
    enDemarrage = false;
  }

  // Etat effectif : la securite locale force DEFAUT
  byte etatCourant = securiteDeclenchee ? ETAT_DEFAUT : etatFPGA;

  // L'Arduino execute le verdict sur le moteur + signale par les LEDs
  if (securiteDeclenchee) couperMoteur();
  else                    reagirSelonEtat(etatCourant);

  mettreAJourLEDs(enDemarrage ? ETAT_NORMAL : etatCourant);

  unsigned long tempsActuel = millis();
  if (tempsActuel - dernierTempsRPM >= intervalleRPM) {

    // --- Vitesse ---
    noInterrupts();
    unsigned long copie = compteurFronts;
    interrupts();
    unsigned long fronts = copie - dernierCompteur;
    dernierCompteur = copie;
    float deltaMinutes = (float)(tempsActuel - dernierTempsRPM) / 60000.0;
    vitesseRPM = ((float)fronts / deltaMinutes) / totalFrontsParTourSortie;
    dernierTempsRPM = tempsActuel;

    // --- Courant ---
    courantMoteur_mA = lireCourant_mA();

    // --- REGULATION : ajuste le PWM pour atteindre la vitesse cible ---
    if (!securiteDeclenchee) {
      if (cibleRPM <= 0.0) {
        pwmRegule = 0.0;
      } else {
        float erreur = cibleRPM - vitesseRPM;
        pwmRegule += erreur * KP;
        pwmRegule = constrain(pwmRegule, 0.0, 255.0);
      }
      consignePWM = (int)pwmRegule;
    }

    // --- Securite locale, independante du FPGA ---
    if (courantMoteur_mA >= seuilCourantDefaut_mA) {
      couperMoteur();
      consignePWM = 0;
      cibleRPM = 0.0;
      pwmRegule = 0.0;
      enDemarrage = false;
      securiteDeclenchee = true;
      etatCourant = ETAT_DEFAUT;
      Serial.println("# SECURITE : courant >= 2000 mA, moteur coupe ! 'r' pour rearmer.");
    }

    // --- Envoi des mesures au FPGA ---
    uint16_t rpmEnvoye = (uint16_t)constrain(round(vitesseRPM),       0, 65535);
    uint16_t curEnvoye = (uint16_t)constrain(round(courantMoteur_mA), 0, 65535);
    envoyerMesuresFPGA(rpmEnvoye, curEnvoye);

    // Une reponse peut arriver juste apres l'envoi
    lireReponseFPGA();
    etatCourant = securiteDeclenchee ? ETAT_DEFAUT : etatFPGA;

    // --- AFFICHAGE : vitesse | courant | etat ---
    Serial.print("Cible : ");
    Serial.print(cibleRPM, 0);
    Serial.print(" | ");
    Serial.print("Vitesse : ");
    Serial.print(vitesseRPM, 1);
    Serial.print(" tr/min | Courant : ");
    Serial.print(courantMoteur_mA, 0);
    Serial.print(" mA | Etat : ");
    Serial.println(enDemarrage ? "DEMARRAGE" : texteEtat(etatCourant));

    nouvelleTrameFPGA = false;
  }
}
