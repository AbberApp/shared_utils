#!/usr/bin/env python3
"""يولّد بيانات أطوال أرقام الهاتف من Google libphonenumber (مرجع واتساب).

الاستخدام:
    python3 -m venv .venv && .venv/bin/pip install phonenumbers
    .venv/bin/python tool/gen_phone_lengths.py

يقرأ قائمة الدول من lib/src/utils/phone/intl_phone_utils.dart (code + dialCode)
ويكتب:
  - lib/src/utils/phone/phone_lengths.g.dart  (أطوال NSN الممكنة لكل دولة + الدولة الرئيسية لكل رمز)
  - test/phone_examples.g.dart                 (رقم مثال حقيقي لكل دولة، لاختبار كل دولة بمعاييرها)

ملاحظة النموذج: هذا التطبيق يطوي رمز منطقة NANP داخل dialCode (مثل AS='1684')،
فتُطرح الأرقام الزائدة عن رمز الدولة من أطوال libphonenumber (extra = len(appDial) - len(libCC)).
بعد التوليد شغّل: flutter test test/phone_validation_test.dart  (يجب أن تنجح كل الدول).
"""
import re
import phonenumbers
from phonenumbers import PhoneMetadata

ROOT = __file__.rsplit('/tool/', 1)[0]
SRC = f'{ROOT}/lib/src/utils/phone/intl_phone_utils.dart'


def app_countries():
    src = open(SRC, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r"'flag':\s*'[^']*'", src):
        nstart = src.rfind("'name':", 0, m.start())
        bend = src.find('\n    },', m.start())
        block = src[nstart:bend]
        code = re.search(r"'code':\s*'([A-Z]{2})'", block)
        dc = re.search(r"'dialCode':\s*'(\d+)'", block)
        if code and dc:
            out.setdefault(code.group(1), dc.group(1))
    return out


def lib_lengths(region):
    """أطوال الرقم الوطني الممكنة لحقل **جوّال** — نعتمد نوع MOBILE حصراً
    (فحقل الدخول جوّال)، ونعود إلى general_desc فقط إن غابت بيانات الجوّال.
    استخدام general/fixed كان يُدخل أطوالاً لا تخصّ الجوّال (مثل SA=10) فيكسر
    اكتشاف اكتمال الرقم."""
    meta = PhoneMetadata.metadata_for_region(region)
    if not meta:
        return []
    desc = meta.mobile if (meta.mobile and meta.mobile.possible_length) else meta.general_desc
    if not desc or not desc.possible_length:
        return []
    return sorted(x for x in desc.possible_length if x > 0)


def main():
    appdc = app_countries()
    lengths, examples, missing = {}, {}, []
    for code, dial in appdc.items():
        try:
            libcc = phonenumbers.country_code_for_region(code)
        except Exception:
            libcc = None
        extra = (len(dial) - len(str(libcc))) if libcc else 0
        ll = lib_lengths(code)
        if not ll:
            missing.append(code)
            continue
        lengths[code] = sorted({L - extra for L in ll if L - extra > 0})
        try:
            ex = (phonenumbers.example_number_for_type(code, phonenumbers.PhoneNumberType.MOBILE)
                  or phonenumbers.example_number(code))
            if ex:
                examples[code] = phonenumbers.format_number(ex, phonenumbers.PhoneNumberFormat.E164)
        except Exception:
            pass

    main_region = {str(cc): regs[0] for cc, regs in phonenumbers.COUNTRY_CODE_TO_REGION_CODE.items()}

    def mil(d):
        return ',\n'.join(f"  '{k}': [{', '.join(map(str, v))}]" for k, v in sorted(d.items()))

    def ms(d):
        return ',\n'.join(f"  '{k}': '{v}'" for k, v in sorted(d.items()))

    open(f'{ROOT}/lib/src/utils/phone/phone_lengths.g.dart', 'w', encoding='utf-8').write(
        "// GENERATED — do not edit by hand. Source: Google libphonenumber (python `phonenumbers`).\n"
        "// Regenerate: python tool/gen_phone_lengths.py  (see file header).\n\n"
        "/// أطوال الرقم الوطني الممكنة لكل دولة — مرجع libphonenumber، معدّلة لنموذج dialCode لدينا.\n"
        f"const Map<String, List<int>> kPhonePossibleLengths = {{\n{mil(lengths)},\n}};\n\n"
        "/// الدولة الرئيسية لكل رمز اتصال (لحسم الأقاليم المتشاركة عند غياب اختيار المستخدم).\n"
        f"const Map<String, String> kMainRegionForDialCode = {{\n{ms(main_region)},\n}};\n")

    open(f'{ROOT}/test/phone_examples.g.dart', 'w', encoding='utf-8').write(
        "// GENERATED test fixture — real libphonenumber example mobile numbers (E164).\n"
        "const Map<String, String> kExampleNumbers = {\n"
        + ',\n'.join(f"  '{k}': '{v}'" for k, v in sorted(examples.items())) + ',\n};\n')

    print(f"countries={len(appdc)} lengths={len(lengths)} examples={len(examples)} "
          f"missing(uninhabited)={missing}")


if __name__ == '__main__':
    main()
