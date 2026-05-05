# ADR-002: NWEB Corporate Design und Theme

Status: Akzeptiert

## Kontext

Die Anwendung soll nicht im Apple-Demo-Look bleiben. Gleichzeitig darf kein Logo
eingebunden werden. Außerdem muss Dark Mode wirklich über die App-Einstellung
steuerbar sein.

## Entscheidung

Die App nutzt das NWEB-Farbsystem mit warmen Flächen, NWEB-Blau als Primärakzent
und Orange/Teal/Purple/Green als eindeutige Pipe- und Modulfarben. Theme-
Umschaltung erfolgt über SwiftUI `preferredColorScheme` aus der gespeicherten
App-Konfiguration.

Für die TestPipes-Oberfläche wurden kontrastfeste eigene Control-Oberflächen für
Dropdowns und sekundäre Buttons ergänzt, damit Dark Mode nicht von schlecht
lesbaren nativen Disabled-Farben abhängt.

## Konsequenzen

- Theme, Debug, Provider, Reasoning und Pfade werden per `UserDefaults`
  gespeichert und in Tests neu geladen.
- Dark Mode bleibt nutzbar und lesbar.
- Farben sind funktional: Source, Operator/WAS, Persona/WER, QS und Output sind
  unterscheidbar.
