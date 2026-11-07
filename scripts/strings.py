#!/usr/bin/env python3
# SPDX-License-Identifier: EUPL-1.2
"""Textes de l'application iOS, dans les six langues de Jalonio (ADR-0028 du dépôt `jalonio`).

Reprend les traductions de l'application Android (`../jalonio-android`, values*/strings.xml)
et y ajoute les textes propres à iOS (EXTRA ci-dessous), puis écrit
Jalonio/Resources/<langue>.lproj/Localizable.strings et Localizable.stringsdict.

    python3 scripts/strings.py [chemin du dépôt Android]

Les fichiers produits sont versionnés : l'application se compile sans le dépôt Android.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "jalonio-android"
RES = ANDROID / "app/src/main/res"
OUT = ROOT / "Jalonio/Resources"
# Dossier Android → dossier iOS ; l'anglais est la langue de repli (comme sur Android).
LANGS = {"values": "en", "values-fr": "fr", "values-de": "de", "values-es": "es", "values-it": "it", "values-pt": "pt"}

# Textes propres à iOS : clé → {langue: texte}
EXTRA = {
    # Tableau Kanban (iPad) : textes repris du tableau web (frontend/messages/board.<langue>.json)
    "close": {"fr": "Fermer", "en": "Close", "de": "Schließen", "es": "Cerrar", "it": "Chiudi", "pt": "Fechar"},
    "board_open": {"fr": "Tableau", "en": "Board", "de": "Board", "es": "Tablero", "it": "Bacheca", "pt": "Quadro"},
    "board_column_empty": {"fr": "Aucun ticket", "en": "No ticket", "de": "Keine Tickets", "es": "Ningún ticket", "it": "Nessun ticket", "pt": "Nenhum ticket"},
    "board_no_sprint_title": {
        "fr": "Aucun sprint en cours.", "en": "No sprint in progress.", "de": "Kein laufender Sprint.",
        "es": "Ningún sprint en curso.", "it": "Nessuno sprint in corso.", "pt": "Nenhum sprint em curso.",
    },
    "board_no_sprint_text": {
        "fr": "Le tableau affiche le sprint en cours. Préparez et démarrez un sprint depuis le backlog.",
        "en": "The board shows the current sprint. Prepare and start a sprint from the backlog.",
        "de": "Das Board zeigt den laufenden Sprint. Bereiten Sie im Backlog einen Sprint vor und starten Sie ihn.",
        "es": "El tablero muestra el sprint en curso. Prepare e inicie un sprint desde el backlog.",
        "it": "La bacheca mostra lo sprint in corso. Preparare e avviare uno sprint dal backlog.",
        "pt": "O quadro mostra o sprint em curso. Prepare e inicie um sprint a partir do backlog.",
    },
    "board_sprint_until": {
        "fr": "%1$@ · jusqu’au %2$@", "en": "%1$@ · until %2$@", "de": "%1$@ · bis %2$@",
        "es": "%1$@ · hasta el %2$@", "it": "%1$@ · fino al %2$@", "pt": "%1$@ · até %2$@",
    },
    "board_move_to": {"fr": "Déplacer vers…", "en": "Move to…", "de": "Verschieben nach…", "es": "Mover a…", "it": "Sposta in…", "pt": "Mover para…"},
    "board_move_to_status": {
        "fr": "Déplacer vers %@", "en": "Move to %@", "de": "Nach %@ verschieben",
        "es": "Mover a %@", "it": "Sposta in %@", "pt": "Mover para %@",
    },
    "board_move_top": {
        "fr": "En haut de la colonne", "en": "Top of the column", "de": "An den Anfang der Spalte",
        "es": "Arriba de la columna", "it": "In cima alla colonna", "pt": "Para o topo da coluna",
    },
    "board_move_bottom": {
        "fr": "En bas de la colonne", "en": "Bottom of the column", "de": "An das Ende der Spalte",
        "es": "Abajo de la columna", "it": "In fondo alla colonna", "pt": "Para o fim da coluna",
    },
    "board_moved": {
        "fr": "%1$@ déplacé dans %2$@.", "en": "%1$@ moved to %2$@.", "de": "%1$@ nach %2$@ verschoben.",
        "es": "%1$@ movido a %2$@.", "it": "%1$@ spostato in %2$@.", "pt": "%1$@ movido para %2$@.",
    },
    "login_fields_missing": {
        "fr": "Saisissez l’adresse de l’espace, votre adresse e-mail et votre mot de passe.",
        "en": "Enter the workspace address, your email address and your password.",
        "de": "Geben Sie die Adresse des Arbeitsbereichs, Ihre E-Mail-Adresse und Ihr Passwort ein.",
        "es": "Introduzca la dirección del espacio de trabajo, su correo electrónico y su contraseña.",
        "it": "Inserisci l’indirizzo dello spazio di lavoro, il tuo indirizzo e-mail e la tua password.",
        "pt": "Introduza o endereço do espaço de trabalho, o seu endereço de e-mail e a sua palavra-passe.",
    },
    "login_code_missing": {
        "fr": "Saisissez le code à 6 chiffres.",
        "en": "Enter the 6-digit code.",
        "de": "Geben Sie den 6-stelligen Code ein.",
        "es": "Introduzca el código de 6 dígitos.",
        "it": "Inserisci il codice a 6 cifre.",
        "pt": "Introduza o código de 6 dígitos.",
    },
    "loading": {
        "fr": "Chargement…", "en": "Loading…", "de": "Wird geladen …", "es": "Cargando…", "it": "Caricamento…", "pt": "A carregar…",
    },
    "error_session_expired": {
        "fr": "Votre session a expiré : reconnectez-vous.",
        "en": "Your session has expired: please sign in again.",
        "de": "Ihre Sitzung ist abgelaufen: Bitte melden Sie sich erneut an.",
        "es": "Su sesión ha caducado: vuelva a iniciar sesión.",
        "it": "La sessione è scaduta: accedi di nuovo.",
        "pt": "A sua sessão expirou: inicie sessão novamente.",
    },
    "project_select": {
        "fr": "Choisissez un projet", "en": "Choose a project", "de": "Wählen Sie ein Projekt", "es": "Elija un proyecto", "it": "Scegli un progetto", "pt": "Escolha um projeto",
    },
    "ticket_select": {
        "fr": "Choisissez un ticket", "en": "Choose a ticket", "de": "Wählen Sie ein Ticket", "es": "Elija un ticket", "it": "Scegli un ticket", "pt": "Escolha um ticket",
    },
    "ticket_select_text": {
        "fr": "Sa fiche s’affiche ici.",
        "en": "Its details appear here.",
        "de": "Die Details erscheinen hier.",
        "es": "Su ficha aparece aquí.",
        "it": "La sua scheda appare qui.",
        "pt": "A sua ficha aparece aqui.",
    },
    "ticket_create_submit": {
        "fr": "Créer", "en": "Create", "de": "Erstellen", "es": "Crear", "it": "Crea", "pt": "Criar",
    },
    "ticket_overdue": {
        "fr": "En retard", "en": "Overdue", "de": "Überfällig", "es": "Atrasado", "it": "In ritardo", "pt": "Em atraso",
    },
    "ticket_resolved": {
        "fr": "Terminé", "en": "Done", "de": "Erledigt", "es": "Terminado", "it": "Completato", "pt": "Concluído",
    },
    "ticket_search": {
        "fr": "Rechercher un ticket", "en": "Search tickets", "de": "Tickets suchen", "es": "Buscar un ticket", "it": "Cerca un ticket", "pt": "Pesquisar um ticket",
    },
    "ticket_status_changed": {
        "fr": "Statut : %@", "en": "Status: %@", "de": "Status: %@", "es": "Estado: %@", "it": "Stato: %@", "pt": "Estado: %@",
    },
    "ticket_comment_sent": {
        "fr": "Commentaire envoyé.", "en": "Comment sent.", "de": "Kommentar gesendet.", "es": "Comentario enviado.", "it": "Commento inviato.", "pt": "Comentário enviado.",
    },
    "ticket_created": {
        "fr": "Ticket %@ créé.", "en": "Ticket %@ created.", "de": "Ticket %@ erstellt.", "es": "Ticket %@ creado.", "it": "Ticket %@ creato.", "pt": "Ticket %@ criado.",
    },
    "account_language_hint": {
        "fr": "La langue de Jalonio se choisit dans les Réglages de l’appareil.",
        "en": "Jalonio’s language is chosen in the device Settings.",
        "de": "Die Sprache von Jalonio wählen Sie in den Einstellungen des Geräts.",
        "es": "El idioma de Jalonio se elige en los Ajustes del dispositivo.",
        "it": "La lingua di Jalonio si sceglie nelle Impostazioni del dispositivo.",
        "pt": "O idioma do Jalonio escolhe-se nas Definições do dispositivo.",
    },
    "account_open_settings": {
        "fr": "Ouvrir les Réglages", "en": "Open Settings", "de": "Einstellungen öffnen", "es": "Abrir Ajustes", "it": "Apri Impostazioni", "pt": "Abrir Definições",
    },
    # Remplace le texte Android (« Ce téléphone… ») : l'application tourne aussi sur iPad.
    "account_logout_confirm": {
        "fr": "Cet appareil sera déconnecté de votre espace. Vos données restent dans Jalonio.",
        "en": "This device will be signed out of your workspace. Your data stays in Jalonio.",
        "de": "Dieses Gerät wird von Ihrem Arbeitsbereich abgemeldet. Ihre Daten bleiben in Jalonio.",
        "es": "Este dispositivo se desconectará de su espacio de trabajo. Sus datos permanecen en Jalonio.",
        "it": "Questo dispositivo verrà disconnesso dallo spazio di lavoro. I dati restano in Jalonio.",
        "pt": "Este dispositivo será desligado do seu espaço de trabalho. Os seus dados permanecem no Jalonio.",
    },
    "unread_count": {
        "fr": "%d non lues", "en": "%d unread", "de": "%d ungelesen", "es": "%d sin leer", "it": "%d non lette", "pt": "%d por ler",
    },
}


def android_text(value: str) -> str:
    """Texte Android → texte iOS : échappements Android, %1$s → %1$@."""
    value = value.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n")
    for i in range(1, 6):
        value = value.replace(f"%{i}$s", f"%{i}$@")
    return value


def strings_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def plist_escape(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main() -> None:
    for folder, lang in LANGS.items():
        tree = ET.parse(RES / folder / "strings.xml")
        strings: dict[str, str] = {}
        plurals: dict[str, dict[str, str]] = {}
        for node in tree.getroot():
            name = node.get("name")
            if node.get("translatable") == "false" or name is None:
                continue
            if node.tag == "string":
                strings[name] = android_text("".join(node.itertext()))
            elif node.tag == "plurals":
                plurals[name] = {item.get("quantity"): android_text("".join(item.itertext())) for item in node}
        for key, texts in EXTRA.items():
            strings[key] = texts[lang]
        target = OUT / f"{lang}.lproj"
        target.mkdir(parents=True, exist_ok=True)
        lines = ["/* SPDX-License-Identifier: EUPL-1.2 */", "/* Produit par scripts/strings.py : ne pas modifier à la main. */", ""]
        lines += [f'"{key}" = "{strings_escape(text)}";' for key, text in sorted(strings.items())]
        (target / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
        entries = []
        for key, forms in sorted(plurals.items()):
            rules = "".join(f"\t\t\t<key>{q}</key>\n\t\t\t<string>{plist_escape(t)}</string>\n" for q, t in forms.items())
            entries.append(
                f"\t<key>{key}</key>\n\t<dict>\n\t\t<key>NSStringLocalizedFormatKey</key>\n\t\t<string>%#@count@</string>\n"
                f"\t\t<key>count</key>\n\t\t<dict>\n\t\t\t<key>NSStringFormatSpecTypeKey</key>\n\t\t\t<string>NSStringPluralRuleType</string>\n"
                f"\t\t\t<key>NSStringFormatValueTypeKey</key>\n\t\t\t<string>d</string>\n{rules}\t\t</dict>\n\t</dict>\n"
            )
        plist = (
            '<?xml version="1.0" encoding="UTF-8"?>\n<!-- SPDX-License-Identifier: EUPL-1.2 -->\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0">\n<dict>\n' + "".join(entries) + "</dict>\n</plist>\n"
        )
        (target / "Localizable.stringsdict").write_text(plist, encoding="utf-8")
        print(f"{lang}: {len(strings)} textes, {len(plurals)} pluriels")


if __name__ == "__main__":
    main()
