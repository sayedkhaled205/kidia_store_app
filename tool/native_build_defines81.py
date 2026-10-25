"""Package only public Native build inputs; never discover or rewrite a design.

APP_DESIGN_BUNDLE must already be the normalized Base64 output of
encodeSavedAppDesign58. This preflight guards the transport/public-data boundary;
AppDesignBundle58 remains the authoritative renderer/layout schema validator.
"""
import argparse
import base64
import json
import math
import os
from pathlib import Path
import re
import sys
from urllib.parse import parse_qsl, quote, unquote, urlsplit


PLATFORMS = {"woocommerce", "shopify", "odoo"}
PAGES = {"home", "category", "catalog", "product", "size_chart", "wishlist", "account"}
SECRET_KEY = re.compile(r"password|secret|credential|token|csrf|session|authorization|api_?key|consumer_?key", re.I)
PRIVATE_VALUE = re.compile(r"^(Bearer\s|shpat_|shpca_|shpss_|shpua_|ck_|cs_|-----BEGIN .*PRIVATE KEY)", re.I)
CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
RECORD_KEYS = set("customer customer_id customers customer_data customer_email email account_data auth orders order order_id addresses address price prices price_minor total_minor regular_price sale_price stock stock_quantity in_stock stock_status inventory demo_catalog products product_records categories payment payments".split())


def reject(message="Invalid public APP_DESIGN_BUNDLE; supply the saved normalized design."):
    raise ValueError(message)


def origin(value, *, clean):
    try:
        uri = urlsplit(value)
        if (uri.scheme != "https" or not uri.hostname or uri.username is not None
                or uri.password is not None or uri.query or uri.fragment
                or uri.port not in (None, 443)
                or (clean and uri.path not in ("", "/"))
                or re.search(r"\s|[\x00-\x1f\x7f]", value)):
            reject("STORE_URL must be the configured HTTPS customer store origin.")
        # WordPress can live in a folder. Both the packaged design and Flutter
        # connection must retain it; two installations on one host are distinct
        # stores, not interchangeable design/customer identities.
        if "//" in uri.path:
            reject()
        segments = []
        for segment in uri.path.rstrip("/").split("/")[1:]:
            decoded = unquote(segment, errors="strict")
            if decoded in (".", "..") or re.search(r"[/\\%\x00-\x1f\x7f]", decoded):
                reject()
            segments.append(quote(decoded, safe="-._~!$&'()*+,;=:@"))
        path = "/" + "/".join(segments) if segments else ""
        host = uri.hostname.lower()
        if ":" in host:
            host = "[" + host + "]"
        return "https://" + host + path
    except (ValueError, TypeError):
        reject("STORE_URL must be the configured HTTPS customer store origin.")


def public_value(value, depth=0):
    if depth > 32:
        reject()
    if isinstance(value, dict):
        if len(value) > 500:
            reject()
        for key, child in value.items():
            if SECRET_KEY.search(key) or key.lower() in RECORD_KEYS:
                reject()
            if key.lower().endswith("_json") and isinstance(child, str):
                public_value(load_json(child), depth + 1)
            public_value(child, depth + 1)
    elif isinstance(value, list):
        if len(value) > 500:
            reject()
        for child in value:
            public_value(child, depth + 1)
    elif isinstance(value, str):
        if len(value) > 100000 or CONTROL.search(value) or PRIVATE_VALUE.search(value):
            reject()
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://|^(javascript|data|file|vbscript):", value, re.I):
            uri = urlsplit(value)
            if (uri.scheme != "https" or not uri.hostname or uri.username is not None
                    or uri.password is not None or any(SECRET_KEY.search(key) or key.lower() in RECORD_KEYS
                        for key, _ in parse_qsl(uri.query, keep_blank_values=True))):
                reject()
    elif isinstance(value, float) and not math.isfinite(value):
        reject()


def load_json(value):
    def unique(pairs):
        result = {}
        for key, child in pairs:
            if key in result:
                reject()
            result[key] = child
        return result
    return json.loads(value, object_pairs_hook=unique, parse_constant=lambda _: reject())


def catalog_query(query, categories, platform):
    if not isinstance(query, dict):
        reject()
    mode = query.get("mode")
    keys = {"kind", "mode", "limit", "sort"}
    if mode == "ids":
        keys.add("ids")
    if categories:
        keys.add("hide_empty")
        if mode == "parent":
            keys.add("parent_id")
    else:
        keys |= {"category": {"category_id"}, "search": {"search"}}.get(mode, set())
    limit = query.get("limit")
    merchandising = {"latest", "featured", "on_sale", "best_selling", "top_rated"}
    if (set(query) - keys or query.get("kind") != ("categories" if categories else "products")
            or mode not in ({"all", "parent", "ids"} if categories else {"all", "ids", "category", "search"} | merchandising)
            or type(limit) is not int or not 1 <= limit <= 100
            or ("sort" in query and query["sort"] not in {"name", "relevance", "newest"})
            or (categories and mode != "ids" and query.get("sort") not in (None, "name"))
            or (categories and "hide_empty" in query and type(query["hide_empty"]) is not bool)):
        reject()
    if categories and mode == "parent" and (type(query.get("parent_id")) is not int
            or query["parent_id"] < 0 or type(query.get("hide_empty")) is not bool):
        reject()
    if categories and mode == "ids" and type(query.get("hide_empty")) is not bool:
        reject()
    if not categories and mode in merchandising and query.get("sort") != "newest":
        reject()
    if mode == "ids":
        ids = query.get("ids")
        if (not isinstance(ids, list) or not ids or len(ids) != limit
                or any(type(item) is not int or item <= 0 for item in ids)
                or len(set(ids)) != len(ids) or query.get("sort", "relevance") != "relevance"):
            reject()
    if mode == "category" and (type(query.get("category_id")) is not int or query["category_id"] <= 0):
        reject()
    if mode == "search" and (not isinstance(query.get("search"), str) or not query["search"].strip() or len(query["search"]) > 80):
        reject()
    if platform != "woocommerce" and mode in merchandising - {"latest"}:
        reject()
    if platform == "shopify" and categories and (query.get("hide_empty") is True
            or (mode == "parent" and query["parent_id"] != 0)):
        reject()
    if platform == "shopify" and not categories and mode != "ids" and limit > 20:
        reject()


def validate_bundle(encoded, platform, store_origin):
    try:
        if not encoded or len(encoded) > 2 * 1024 * 1024:
            reject()
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > 1024 * 1024:
            reject()
        bundle = load_json(raw.decode("utf-8"))
        if (not isinstance(bundle, dict)
                or set(bundle) != {"schema_version", "platform", "store_origin", "identity", "splash", "home", "pages"}
                or type(bundle["schema_version"]) is not int or bundle["schema_version"] != 1
                or bundle["platform"] != platform
                or origin(bundle["store_origin"], clean=platform != "woocommerce") != store_origin
                or any(not isinstance(bundle[key], dict) for key in ("identity", "splash", "home", "pages"))
                or set(bundle["pages"]) != PAGES):
            reject()
        public_value(bundle)
        blocks = bundle["home"].get("blocks")
        if not isinstance(blocks, list) or len(blocks) > 100:
            reject()
        for block in blocks:
            if not isinstance(block, dict) or not isinstance(block.get("data"), dict):
                reject()
            kind, data = block.get("type"), block["data"]
            if kind in {"brand_carousel", "bundle_collection"}:
                reject()
            if kind in {"product_grid", "product_carousel", "category_grid"}:
                if data.get("items") != [] or set(data) & {"source", "product_ids", "category_ids"}:
                    reject()
                catalog_query(block.get("catalog_query"), kind == "category_grid", platform)
            elif "catalog_query" in block:
                reject()
    except (ValueError, TypeError, KeyError, RecursionError, UnicodeError):
        reject()


def native_defines(environment):
    platform = environment.get("STORE_PLATFORM", "woocommerce").strip().lower()
    if platform not in PLATFORMS:
        reject("STORE_PLATFORM must be woocommerce, shopify or odoo.")
    store_origin = origin(environment.get("STORE_URL", ""), clean=platform != "woocommerce")
    result = {"STORE_PLATFORM": platform}
    if environment.get("MOBISHOP_ANDROID_BUILD_MODE") == "qa":
        result["APP_TEST_BUILD"] = True
    bundle = environment.get("APP_DESIGN_BUNDLE", "")
    if platform != "woocommerce" or bundle:
        validate_bundle(bundle, platform, store_origin)
        result["APP_DESIGN_BUNDLE"] = bundle  # Preserve exact public design/selectors.
    update_url = environment.get("APP_DESIGN_UPDATE_URL", "").strip()
    if update_url:
        if not bundle or not re.fullmatch(r"https://api\.woomobile\.app/v1/app-design/[a-f0-9-]{36}", update_url):
            reject("Invalid public design update endpoint.")
        result["APP_DESIGN_UPDATE_URL"] = update_url
    token = environment.get("SHOPIFY_PUBLIC_STOREFRONT_TOKEN", "").strip()
    if (len(token) > 512 or re.search(r"\s|[\x00-\x1f\x7f]", token) or PRIVATE_VALUE.search(token)):
        reject("Only a public Shopify Storefront token may be packaged.")
    if platform == "shopify":
        if not re.fullmatch(r"https://[a-z0-9][a-z0-9-]*\.myshopify\.com", store_origin):
            reject("Shopify requires its canonical HTTPS myshopify.com origin.")
        version = environment.get("SHOPIFY_STOREFRONT_API_VERSION", "2026-10")
        language = environment.get("SHOPIFY_LANGUAGE_CODE", "").strip().upper()
        locale = environment.get("STORE_LOCALE", "en") or "en"
        country = environment.get("STORE_COUNTRY_CODE", "").strip().upper()
        if (not re.fullmatch(r"20\d{2}-(01|04|07|10)", version)
                or not re.fullmatch(r"[A-Z]{2}(_[A-Z]{2})?", language or re.split(r"[-_]", locale)[0].upper())
                or (country and not re.fullmatch(r"[A-Z]{2}", country))):
            reject("Invalid public Shopify API version or buyer context.")
        result.update(SHOPIFY_STOREFRONT_API_VERSION=version, SHOPIFY_PUBLIC_STOREFRONT_TOKEN=token,
                      SHOPIFY_LANGUAGE_CODE=language, STORE_COUNTRY_CODE=country)
    elif token:
        reject("A Shopify public token belongs only to a Shopify build.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        defines = native_defines(os.environ)
        Path(args.output).write_text(json.dumps(defines, ensure_ascii=False), encoding="utf-8")
    except (ValueError, OSError) as error:
        # Configuration errors are fixed messages; never echo JSON/token inputs.
        print(str(error) if isinstance(error, ValueError) else "Could not write Native build definitions.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
