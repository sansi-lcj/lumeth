#!/usr/bin/env python3

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = os.environ.get("ASC_API_BASE", "https://api.appstoreconnect.apple.com")
KEY_ID = os.environ.get("ASC_KEY_ID", "")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.sansi.lumeth")
KEY_PATH = os.path.expanduser(
    os.environ.get(
        "ASC_KEY_PATH",
        f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8",
    )
)

DEFAULT_NOTES = (
    "Lumeth is a macOS accessory app (LSUIElement) with no Dock icon. "
    "It uses public, read-only system counters and IOHID temperature events. "
    "It does not request Accessibility, Input Monitoring, Full Disk Access, "
    "root privileges, or network access. No login is required."
)


def log(message):
    print(message, file=sys.stderr, flush=True)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def read_der_length(data, offset):
    first = data[offset]
    if first < 0x80:
        return first, offset + 1
    count = first & 0x7F
    return int.from_bytes(data[offset + 1 : offset + 1 + count], "big"), offset + 1 + count


def der_to_raw(signature):
    if signature[0] != 0x30:
        raise ValueError("Invalid ECDSA signature")
    _, offset = read_der_length(signature, 1)
    if signature[offset] != 0x02:
        raise ValueError("Invalid ECDSA R value")
    r_length, offset = read_der_length(signature, offset + 1)
    r = int.from_bytes(signature[offset : offset + r_length], "big")
    offset += r_length
    if signature[offset] != 0x02:
        raise ValueError("Invalid ECDSA S value")
    s_length, offset = read_der_length(signature, offset + 1)
    s = int.from_bytes(signature[offset : offset + s_length], "big")
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def jwt_token():
    if not KEY_ID or not ISSUER_ID:
        raise RuntimeError("ASC_KEY_ID and ASC_ISSUER_ID are required")
    if not os.path.exists(KEY_PATH):
        raise RuntimeError(f"App Store Connect API key not found: {KEY_PATH}")

    now = int(time.time())
    header = b64url(
        json.dumps(
            {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"},
            separators=(",", ":"),
        ).encode()
    )
    payload = b64url(
        json.dumps(
            {
                "iss": ISSUER_ID,
                "iat": now,
                "exp": now + 900,
                "aud": "appstoreconnect-v1",
            },
            separators=(",", ":"),
        ).encode()
    )
    signing_input = header + b"." + payload
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
        input=signing_input,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return (signing_input + b"." + b64url(der_to_raw(result.stdout))).decode()


TOKEN = None


def request(method, path, params=None, body=None):
    global TOKEN
    if TOKEN is None:
        TOKEN = jwt_token()

    url = API_BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    data = None
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode()

    for attempt in range(5):
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {TOKEN}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            detail = error.read().decode()
            if error.code == 401 and attempt == 0:
                TOKEN = jwt_token()
                continue
            if error.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"{method} {path} failed ({error.code}): {detail}")
    raise RuntimeError(f"{method} {path} failed after retries")


def upload_operation(operation, chunk):
    headers = {
        header["name"]: header["value"]
        for header in operation.get("requestHeaders", [])
    }
    request_object = urllib.request.Request(
        operation["url"],
        data=chunk,
        method=operation["method"],
        headers=headers,
    )
    with urllib.request.urlopen(request_object, timeout=120) as response:
        if response.status not in (200, 201):
            raise RuntimeError(f"Screenshot upload failed with {response.status}")


def get_app_id():
    response = request(
        "GET",
        "/v1/apps",
        {"filter[bundleId]": BUNDLE_ID, "limit": "1"},
    )
    if not response.get("data"):
        raise RuntimeError(f"App Store Connect app not found: {BUNDLE_ID}")
    return response["data"][0]["id"]


def list_versions(app_id, version=None):
    params = {
        "filter[platform]": "MAC_OS",
        "include": "appStoreVersionLocalizations",
        "limit": "50",
    }
    if version:
        params["filter[versionString]"] = version
    return request("GET", f"/v1/apps/{app_id}/appStoreVersions", params)


def select_version(app_id, version):
    response = list_versions(app_id, version)
    exact = [
        item
        for item in response.get("data", [])
        if item["attributes"]["versionString"] == version
    ]
    included = {item["id"]: item for item in response.get("included", [])}
    return exact[0] if exact else None, included


def source_version(app_id, exclude_version_id=None):
    response = list_versions(app_id)
    versions = [
        item
        for item in response.get("data", [])
        if item["id"] != exclude_version_id
    ]
    if not versions:
        raise RuntimeError("No previous App Store version is available to copy")
    versions.sort(key=lambda item: item["attributes"]["createdDate"], reverse=True)
    included = {item["id"]: item for item in response.get("included", [])}
    return versions[0], included


def version_localizations(version_id):
    response = request(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        {"limit": "50"},
    )
    return response.get("data", [])


def source_localization(source):
    version, included = source
    relationships = version.get("relationships", {})
    localizations = relationships.get("appStoreVersionLocalizations", {}).get("data", [])
    for reference in localizations:
        item = included.get(reference["id"])
        if item and item["attributes"].get("locale") == "en-US":
            return item
    for localization in version_localizations(version["id"]):
        if localization["attributes"].get("locale") == "en-US":
            return localization
    return None


def create_version(app_id, version, source):
    source_attributes = source[0]["attributes"]
    body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "platform": "MAC_OS",
                "versionString": version,
                "copyright": source_attributes.get("copyright") or "Lumeth",
                "reviewType": "APP_STORE",
                "releaseType": "AFTER_APPROVAL",
                "usesIdfa": False,
            },
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
            },
        }
    }
    return request("POST", "/v1/appStoreVersions", body=body)["data"]


def update_version(version_id):
    body = {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {
                "reviewType": "APP_STORE",
                "releaseType": "AFTER_APPROVAL",
                "usesIdfa": False,
            },
        }
    }
    request("PATCH", f"/v1/appStoreVersions/{version_id}", body=body)


def ensure_localization(version_id, source, release_notes):
    existing = version_localizations(version_id)
    locale = next(
        (
            item
            for item in existing
            if item["attributes"].get("locale") == "en-US"
        ),
        None,
    )
    previous = source_localization(source)
    if not previous:
        raise RuntimeError("Previous version has no en-US localization")

    previous_attributes = previous["attributes"]
    attributes = {
        "description": previous_attributes.get("description"),
        "keywords": previous_attributes.get("keywords"),
        "marketingUrl": previous_attributes.get("marketingUrl"),
        "promotionalText": previous_attributes.get("promotionalText"),
        "supportUrl": previous_attributes.get("supportUrl"),
        "whatsNew": (release_notes or "Bug fixes and performance improvements.")[:4000],
    }
    attributes = {key: value for key, value in attributes.items() if value}

    if locale:
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": locale["id"],
                "attributes": attributes,
            }
        }
        request(
            "PATCH",
            f"/v1/appStoreVersionLocalizations/{locale['id']}",
            body=body,
        )
    else:
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": "en-US", **attributes},
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        }
        request("POST", "/v1/appStoreVersionLocalizations", body=body)


def wait_for_screenshot(screenshot_id):
    for _ in range(60):
        response = request("GET", f"/v1/appScreenshots/{screenshot_id}")["data"]
        state = (
            response.get("attributes", {})
            .get("assetDeliveryState", {})
            .get("state")
        )
        if state == "COMPLETE":
            return
        if state in ("FAILED", "INVALID"):
            raise RuntimeError(f"Screenshot processing failed: {screenshot_id}")
        time.sleep(5)
    raise RuntimeError(f"Timed out waiting for screenshot: {screenshot_id}")


def upload_screenshot(set_id, path):
    with open(path, "rb") as file:
        data = file.read()
    checksum = hashlib.md5(data).hexdigest()
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": os.path.basename(path),
                "fileSize": len(data),
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            },
        }
    }
    screenshot = request("POST", "/v1/appScreenshots", body=body)["data"]
    for operation in screenshot["attributes"].get("uploadOperations", []):
        offset = operation["offset"]
        length = operation["length"]
        upload_operation(operation, data[offset : offset + length])
    request(
        "PATCH",
        f"/v1/appScreenshots/{screenshot['id']}",
        body={
            "data": {
                "type": "appScreenshots",
                "id": screenshot["id"],
                "attributes": {
                    "sourceFileChecksum": checksum,
                    "uploaded": True,
                },
            }
        },
    )
    wait_for_screenshot(screenshot["id"])


def ensure_screenshots(version_id):
    localizations = version_localizations(version_id)
    localization = next(
        (
            item
            for item in localizations
            if item["attributes"].get("locale") == "en-US"
        ),
        None,
    )
    if not localization:
        raise RuntimeError("New version has no en-US localization")

    response = request(
        "GET",
        f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets",
        {"include": "appScreenshots", "limit": "50"},
    )
    included = {item["id"]: item for item in response.get("included", [])}
    desktop = None
    for item in response.get("data", []):
        if item["attributes"].get("screenshotDisplayType") == "APP_DESKTOP":
            desktop = item
            break

    if desktop:
        references = (
            desktop.get("relationships", {})
            .get("appScreenshots", {})
            .get("data", [])
        )
        if any(reference["id"] in included for reference in references):
            return
        set_id = desktop["id"]
    else:
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": "APP_DESKTOP"},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": localization["id"],
                        }
                    }
                },
            }
        }
        set_id = request("POST", "/v1/appScreenshotSets", body=body)["data"]["id"]

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    screenshots = [
        os.path.join(root, "docs", "screenshot-overview-2560x1600.png"),
        os.path.join(root, "docs", "screenshot-cpu-2560x1600.png"),
    ]
    for path in screenshots:
        if not os.path.exists(path):
            raise RuntimeError(f"Missing screenshot: {path}")
        upload_screenshot(set_id, path)


def ensure_review_detail(version_id, source):
    detail = request(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail",
    ).get("data")
    if detail:
        return

    source_detail = request(
        "GET",
        f"/v1/appStoreVersions/{source[0]['id']}/appStoreReviewDetail",
    ).get("data")
    attributes = {}
    if source_detail:
        source_attributes = source_detail["attributes"]
        attributes = {
            "contactFirstName": source_attributes.get("contactFirstName"),
            "contactLastName": source_attributes.get("contactLastName"),
            "contactPhone": source_attributes.get("contactPhone"),
            "contactEmail": source_attributes.get("contactEmail"),
        }
    else:
        attributes = {
            "contactFirstName": os.environ.get("ASC_REVIEW_FIRST_NAME"),
            "contactLastName": os.environ.get("ASC_REVIEW_LAST_NAME"),
            "contactPhone": os.environ.get("ASC_REVIEW_PHONE"),
            "contactEmail": os.environ.get("ASC_REVIEW_EMAIL"),
        }
    if not all(attributes.values()):
        raise RuntimeError(
            "No previous review contact and ASC_REVIEW_* fallback values are incomplete"
        )
    attributes.update(
        {
            "demoAccountRequired": False,
            "notes": DEFAULT_NOTES,
        }
    )
    body = {
        "data": {
            "type": "appStoreReviewDetails",
            "attributes": attributes,
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            },
        }
    }
    request("POST", "/v1/appStoreReviewDetails", body=body)


def prepare(args):
    app_id = get_app_id()
    version, _ = select_version(app_id, args.version)
    if version:
        state = version["attributes"].get("appStoreState")
        if state not in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"):
            log(f"Version is already {state}; metadata sync skipped")
            return version["id"]

    source = source_version(app_id, version["id"] if version else None)
    if not version:
        log(f"Creating App Store version {args.version}")
        version = create_version(app_id, args.version, source)
    else:
        log(f"Using App Store version {args.version}")

    update_version(version["id"])
    ensure_localization(version["id"], source, args.release_notes)
    ensure_screenshots(version["id"])
    ensure_review_detail(version["id"], source)
    log(f"Prepared App Store version {args.version}")
    return version["id"]


def find_build(app_id, version, build_number):
    params = {
        "filter[app]": app_id,
        "filter[version]": build_number,
        "filter[preReleaseVersion.version]": version,
        "include": "preReleaseVersion",
        "limit": "10",
    }
    return request("GET", "/v1/builds", params).get("data", [])


def wait_for_build(app_id, version, build_number):
    for _ in range(50):
        builds = find_build(app_id, version, build_number)
        for build in builds:
            state = build["attributes"].get("processingState")
            if state == "VALID":
                return build
            if state in ("FAILED", "INVALID"):
                raise RuntimeError(
                    f"Build {build_number} processing failed: {state}"
                )
        time.sleep(30)
    raise RuntimeError(f"Timed out waiting for build {version} ({build_number})")


def active_submission(app_id):
    response = request(
        "GET",
        f"/v1/apps/{app_id}/reviewSubmissions",
        {"limit": "20"},
    )
    for item in response.get("data", []):
        if item["attributes"].get("state") in (
            "READY_FOR_REVIEW",
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
        ):
            return item
    return None


def submit(args):
    app_id = get_app_id()
    version, _ = select_version(app_id, args.version)
    if not version:
        raise RuntimeError(f"App Store version {args.version} does not exist")
    state = version["attributes"].get("appStoreState")
    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
        log(f"Version {args.version} is already {state}")
        return
    if state not in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"):
        raise RuntimeError(f"Version cannot be submitted from state {state}")

    build = wait_for_build(app_id, args.version, args.build_number)
    request(
        "PATCH",
        f"/v1/appStoreVersions/{version['id']}",
        body={
            "data": {
                "type": "appStoreVersions",
                "id": version["id"],
                "relationships": {
                    "build": {
                        "data": {"type": "builds", "id": build["id"]}
                    }
                },
            }
        },
    )

    submission = active_submission(app_id)
    if submission and submission["attributes"].get("state") != "READY_FOR_REVIEW":
        raise RuntimeError(
            f"Another review submission is already {submission['attributes']['state']}"
        )
    if not submission:
        submission = request(
            "POST",
            "/v1/reviewSubmissions",
            body={
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "MAC_OS"},
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}}
                    },
                }
            },
        )["data"]
    request(
        "POST",
        "/v1/reviewSubmissionItems",
        body={
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {
                        "data": {
                            "type": "reviewSubmissions",
                            "id": submission["id"],
                        }
                    },
                    "appStoreVersion": {
                        "data": {
                            "type": "appStoreVersions",
                            "id": version["id"],
                        }
                    },
                },
            }
        },
    )
    submission = request(
        "PATCH",
        f"/v1/reviewSubmissions/{submission['id']}",
        body={
            "data": {
                "type": "reviewSubmissions",
                "id": submission["id"],
                "attributes": {"submitted": True},
            }
        },
    )["data"]
    log(f"Submitted {args.version} ({args.build_number}): {submission['attributes']['state']}")


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("--version", required=True)
    prepare_parser.add_argument("--release-notes", default="")
    prepare_parser.set_defaults(func=prepare)

    submit_parser = subparsers.add_parser("submit")
    submit_parser.add_argument("--version", required=True)
    submit_parser.add_argument("--build-number", required=True)
    submit_parser.set_defaults(func=submit)

    args = parser.parse_args()
    if not re.fullmatch(r"\d+(?:\.\d+){1,2}", args.version):
        raise RuntimeError(f"Invalid marketing version: {args.version}")
    args.func(args)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        log(str(error))
        sys.exit(1)
