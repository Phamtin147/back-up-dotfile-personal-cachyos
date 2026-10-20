import locale
import json
import glob
import os


class Translation:
    _translations_path = os.path.join(os.path.dirname(__file__), 'translations')
    _translations = {}
    _default_translations = {}
    lang_code = "en"

    @staticmethod
    def select_language(lang_code="auto"):
        if not lang_code or lang_code == "auto":
            lang_code = "en"
            try:
                loc = locale.getlocale()[0] or os.environ.get("LANG", "en")
                lang = loc.split("_")[0]
                if lang:
                    lang_code = lang
            except Exception:
                lang_code = "en"

        if lang_code in Translation.available_languages():
            Translation.lang_code = lang_code
        else:
            Translation.lang_code = "en"

        Translation._load_lang(Translation.lang_code)

    @staticmethod
    def _load_lang(lang_code):
        file_path = os.path.join(Translation._translations_path, f"{lang_code}.json")
        if os.path.isfile(file_path):
            try:
                with open(file_path, "r", encoding="utf-8") as json_file:
                    Translation._translations = json.load(json_file)
            except Exception:
                Translation._translations = {}

        file_path_en = os.path.join(Translation._translations_path, "en.json")
        if os.path.isfile(file_path_en):
            try:
                with open(file_path_en, "r", encoding="utf-8") as json_file:
                    Translation._default_translations = json.load(json_file)
            except Exception:
                Translation._default_translations = {}

    @staticmethod
    def available_languages():
        return [os.path.splitext(os.path.basename(x))[0] for x in glob.glob(Translation._translations_path + '/*.json')]

    @staticmethod
    def t(translation):
        if not Translation._translations:
            Translation.select_language()
        if translation in Translation._translations:
            return Translation._translations[translation]
        elif translation in Translation._default_translations:
            return Translation._default_translations[translation]
        return translation
