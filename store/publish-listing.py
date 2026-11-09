# SPDX-License-Identifier: EUPL-1.2
"""Fiche App Store de Jalonio envoyée par l'API App Store Connect.

Textes dans store/fiche/<langue>/, captures dans store/captures/ (workflow « Captures »).
La clé d'API reste hors du dépôt et n'est jamais affichée ; le mot de passe du compte de
démonstration et le contact pour Apple (dépôt public : rien de personnel ici) viennent de
l'environnement :

    JALONIO_DEMO_PASSWORD=… JALONIO_REVIEW_CONTACT="Prénom|Nom|+33 6 …" \
        python3 store/publish-listing.py [--captures]

Sans --captures, seuls les textes, catégories, classement par âge et informations de
vérification sont envoyés. Ce que l'API ne permet pas (confidentialité de l'app, prix)
se fait dans App Store Connect (docs/app-store.md).
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

KEY_ID = os.environ.get("ASC_KEY_ID", "VRMQN6YM7C")
ISSUER = os.environ.get("ASC_ISSUER_ID", "906be997-abb7-40aa-bf74-48ef0a70a28c")
KEY_PATH = Path(os.environ.get("ASC_KEY_PATH", f"~/jalonio-keystore/AuthKey_{KEY_ID}.p8")).expanduser()
BUNDLE_ID = "fr.jalonio.app"
VERSION = "1.0.0"
COPYRIGHT = "2026 KersAI Factory"
PRIVACY_URL = "https://app.jalonio.fr/confidentialite/"
REVIEW = {"demoAccountName": "demo@jalonio.fr", "contactEmail": "contact@jalonio.fr"}
ROOT = Path(__file__).resolve().parent
LOCALES = ["fr-FR", "en-US", "de-DE", "es-ES", "it", "pt-PT"]
# Captures : nom du fichier (sans extension) → type d'écran d'App Store Connect
DISPLAYS = {"iphone": "APP_IPHONE_67", "ipad": "APP_IPAD_PRO_3GEN_129"}

_key = KEY_PATH.read_text()


def call(method, path, body=None):
    token = jwt.encode({"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600,
                        "aud": "appstoreconnect-v1"}, _key, algorithm="ES256", headers={"kid": KEY_ID})
    url = path if path.startswith("http") else "https://api.appstoreconnect.apple.com" + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{method} {path} → {error.code} {error.read().decode()[:2000]}")


def text(locale, name):
    return (ROOT / "fiche" / locale / f"{name}.txt").read_text().strip()


def upsert(kind, existing, attributes, parent_type, parent_id, parent_rel):
    """Met à jour la ressource de la langue si elle existe, sinon la crée."""
    if existing:
        call("PATCH", f"/v1/{kind}/{existing['id']}",
             {"data": {"type": kind, "id": existing["id"], "attributes": attributes}})
    else:
        call("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": attributes,
             "relationships": {parent_rel: {"data": {"type": parent_type, "id": parent_id}}}}})


def main():
    app = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    info = next(i for i in call("GET", f"/v1/apps/{app['id']}/appInfos")["data"]
                if i["attributes"]["state"] != "READY_FOR_DISTRIBUTION")
    version = next(v for v in call("GET", f"/v1/apps/{app['id']}/appStoreVersions")["data"]
                   if v["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION")
    urls = json.loads((ROOT / "fiche" / "urls.json").read_text())

    # Nom, sous-titre, politique de confidentialité
    current = {l["attributes"]["locale"]: l for l in
               call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]}
    for locale in LOCALES:
        attributes = {"name": text(locale, "name"), "subtitle": text(locale, "subtitle"),
                      "privacyPolicyUrl": PRIVACY_URL}
        if locale not in current:
            attributes["locale"] = locale
        upsert("appInfoLocalizations", current.get(locale), attributes, "appInfos", info["id"], "appInfo")
        print(f"✓ nom et sous-titre ({locale})")

    # Catégories : Économie et entreprise, puis Productivité
    call("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "BUSINESS"}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}}}}})
    print("✓ catégories")

    # Version et droits sur le contenu
    call("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {"type": "appStoreVersions", "id": version["id"],
         "attributes": {"versionString": VERSION, "copyright": COPYRIGHT}}})
    call("PATCH", f"/v1/apps/{app['id']}", {"data": {"type": "apps", "id": app["id"],
         "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    print(f"✓ version {VERSION}, droits d'auteur")

    # Dernier build valide de cette version (celui qu'Apple examinera)
    builds = call("GET", f"/v1/builds?filter[app]={app['id']}&filter[preReleaseVersion.version]={VERSION}"
                         "&filter[processingState]=VALID&sort=-uploadedDate&limit=1")["data"]
    if builds:
        call("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
             {"data": {"type": "builds", "id": builds[0]["id"]}})
        print(f"✓ build {builds[0]['attributes']['version']} rattaché")

    # Description, mots-clés, texte promotionnel, adresses
    current = {l["attributes"]["locale"]: l for l in
               call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]}
    for locale in LOCALES:
        attributes = {"description": text(locale, "description"), "keywords": text(locale, "keywords"),
                      "promotionalText": text(locale, "promotional_text"),
                      "supportUrl": urls[locale]["support"], "marketingUrl": urls[locale]["marketing"]}
        if locale not in current:
            attributes["locale"] = locale
        upsert("appStoreVersionLocalizations", current.get(locale), attributes,
               "appStoreVersions", version["id"], "appStoreVersion")
        print(f"✓ description ({locale})")

    # Informations pour la vérification (compte de démonstration)
    password = os.environ.get("JALONIO_DEMO_PASSWORD")
    contact = os.environ.get("JALONIO_REVIEW_CONTACT", "").split("|")
    if password and len(contact) == 3:
        first_name, last_name, phone = (part.strip() for part in contact)
        attributes = dict(REVIEW, demoAccountRequired=True, demoAccountPassword=password,
                          contactFirstName=first_name, contactLastName=last_name, contactPhone=phone,
                          notes=(ROOT / "fiche" / "review-notes.txt").read_text().strip())
        existing = call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
        upsert("appStoreReviewDetails", existing, attributes, "appStoreVersions", version["id"], "appStoreVersion")
        print("✓ compte de démonstration et notes pour la vérification")
    else:
        print("… JALONIO_DEMO_PASSWORD ou JALONIO_REVIEW_CONTACT absent : informations de vérification non envoyées")

    if "--captures" in sys.argv:
        upload_screenshots(version)


def upload_screenshots(version):
    """Captures de store/captures/ (iphone-*.png, ipad-*.png), en français : App Store
    Connect les reprend pour les autres langues tant qu'elles n'ont pas les leurs."""
    localization = next(l for l in call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
                        if l["attributes"]["locale"] == "fr-FR")
    sets = {s["attributes"]["screenshotDisplayType"]: s for s in
            call("GET", f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets")["data"]}
    for prefix, display in DISPLAYS.items():
        files = sorted((ROOT / "captures").glob(f"{prefix}-*.png"))
        if not files:
            continue
        if display in sets:
            # On remplace : les anciennes captures du jeu sont supprimées
            for old in call("GET", f"/v1/appScreenshotSets/{sets[display]['id']}/appScreenshots")["data"]:
                call("DELETE", f"/v1/appScreenshots/{old['id']}")
            screenshot_set = sets[display]
        else:
            screenshot_set = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display}, "relationships": {"appStoreVersionLocalization":
                {"data": {"type": "appStoreVersionLocalizations", "id": localization["id"]}}}}})["data"]
        for file in files:
            content = file.read_bytes()
            screenshot = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
                "attributes": {"fileName": file.name, "fileSize": len(content)}, "relationships": {"appScreenshotSet":
                {"data": {"type": "appScreenshotSets", "id": screenshot_set["id"]}}}}})["data"]
            for operation in screenshot["attributes"]["uploadOperations"]:
                part = content[operation["offset"]:operation["offset"] + operation["length"]]
                headers = {h["name"]: h["value"] for h in operation["requestHeaders"]}
                urllib.request.urlopen(urllib.request.Request(operation["url"], data=part,
                                       method=operation["method"], headers=headers), timeout=120).read()
            call("PATCH", f"/v1/appScreenshots/{screenshot['id']}", {"data": {"type": "appScreenshots",
                 "id": screenshot["id"], "attributes": {"uploaded": True,
                 "sourceFileChecksum": hashlib.md5(content).hexdigest()}}})
            print(f"✓ capture {file.name} ({display})")


if __name__ == "__main__":
    main()
