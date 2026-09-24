<p align="center">
  <img src="docs/icon.png" width="128" alt="অভ্র কিবোর্ডের আইকন">
</p>

<h1 align="center">macOS-এর জন্য অভ্র কিবোর্ড</h1>

<p align="center">
  ম্যাকের জন্য নেটিভ বাংলা ইনপুট মেথড। অভ্র ফোনেটিক, প্রভাত ও ইউনিজয় লেআউট,
  আর ইউনিকোড অথবা ANSI (বিজয়) আউটপুট।
</p>

<p align="center">
  <a href="https://github.com/AminulBD/iAvro/releases/latest"><strong>ডাউনলোড</strong></a> ·
  <a href="https://avro.aminul.dev/bn.html">ওয়েবসাইট</a> ·
  <a href="https://github.com/AminulBD/iAvro/issues">সমস্যা জানান</a>
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>বাংলা</strong>
</p>

<p align="center"><sub>
  Avro Keyboard নাম ও লোগোর স্বত্ব © <a href="https://www.omicronlab.com">OmicronLab</a>, সর্বস্বত্ব সংরক্ষিত।
  এটি একটি স্বাধীন, কমিউনিটি-পরিচালিত ফর্ক। মেহদী হাসান খান ও OmicronLab টিমের প্রতি
  আন্তরিক কৃতজ্ঞতা, যাঁদের কাজ লক্ষ লক্ষ মানুষের জন্য বাংলা লেখা বিনামূল্যে ও সহজলভ্য করেছে।
</sub></p>

---

> [!IMPORTANT]
> **আগে মূল iAvro ইনস্টল করা ছিল?** তাহলে এটা ইনস্টল করার আগে সেটি রিমুভ
> করুন, নইলে ইনপুট মেনুতে দুটি **Avro Keyboard** দেখাবে এবং macOS হয়তো
> পুরনোটিই চালু করতে থাকবে। দেখুন [পুরনো সংস্করণ সরানো](#পুরনো-সংস্করণ-সরানো)।

> [!TIP]
> **নতুন: ANSI (বিজয়) আউটপুট।** এখন অভ্র দিয়ে SutonnyMJ সহ অন্যান্য বিজয়
> ফন্টের জন্য পুরনো বিজয় এনকোডিংয়ে লেখা যায়, তিনটি লেআউটেই। দেখুন
> [ANSI (বিজয়) আউটপুট](#ansi-বিজয়-আউটপুট)।

- [স্ক্রিনশট](#স্ক্রিনশট)
- [কিবোর্ড লেআউট](#কিবোর্ড-লেআউট)
- [ANSI (বিজয়) আউটপুট](#ansi-বিজয়-আউটপুট)
- [সমর্থিত macOS সংস্করণ](#সমর্থিত-macos-সংস্করণ)
- [ইনস্টলেশন](#ইনস্টলেশন)
  - [পুরনো সংস্করণ সরানো](#পুরনো-সংস্করণ-সরানো)
  - [Homebrew](#homebrew)
  - [ম্যানুয়ালি](#ম্যানুয়ালি)
- [বিল্ড করা](#বিল্ড-করা)
- [কন্টিনিউয়াস ইন্টিগ্রেশন](#কন্টিনিউয়াস-ইন্টিগ্রেশন)
  - [রিলিজ](#রিলিজ)
  - [সাইনিং ও নোটারাইজেশন](#সাইনিং-ও-নোটারাইজেশন)
- [লাইসেন্স](#লাইসেন্স)

## স্ক্রিনশট

<p align="center">
  <img src="docs/assets/screenshots/avro-phonetic-typing.png" width="560" alt="Notes-এ “tumi” লেখা হচ্ছে, ক্যান্ডিডেট বারে তুমি ও অন্যান্য বানান দেখাচ্ছে">
</p>

<p align="center">
  <img src="docs/assets/screenshots/avro-switching-between-layouts.png" width="49%" alt="Preferences উইন্ডোতে Keyboard Layout পপ-আপে অভ্র ফোনেটিক, প্রভাত ও ইউনিজয়">
  <img src="docs/assets/screenshots/avro-preferences.png" width="49%" alt="ইনপুট মেনুতে Avro Keyboard নির্বাচিত, নিচে Preferences">
</p>

উচ্চারণ অনুযায়ী ইংরেজি হরফে লিখে ক্যান্ডিডেট বার থেকে বানান বেছে নিন, অথবা
**Preferences… › Keyboard Layout** থেকে প্রভাত বা ইউনিজয় লেআউটে যান।

## কিবোর্ড লেআউট

তিনটি লেআউট আছে। **Preferences… › Keyboard Layout** থেকে একটি বেছে নিন;
পরের কি চাপা থেকেই নতুন লেআউট কাজ করবে।

| লেআউট | কীভাবে কাজ করে |
| --- | --- |
| **অভ্র ফোনেটিক** (ডিফল্ট) | যেমন উচ্চারণ তেমন ইংরেজি হরফে বাংলা লিখুন: `ami` লিখলে `আমি` হয়ে যাবে। ক্যান্ডিডেট, ডিকশনারি সাজেশন ও অটো-কারেক্ট শুধু এই লেআউটেই কাজ করে। |
| **প্রভাত** | প্রতিটি কি সরাসরি একটি বাংলা অক্ষর লেখে: <kbd>k</kbd> ক, <kbd>v</kbd> আ, <kbd>/</kbd> হসন্ত। উইন্ডোজের অভ্র কিবোর্ডের প্রভাতের মতোই কি-ম্যাপ। |
| **ইউনিজয়** | বিজয়ের মতই লেআউট: <kbd>j</kbd> ক, <kbd>f</kbd> া, <kbd>g</kbd> হসন্ত, m17n-এর `bn-unijoy` টেবিল অনুযায়ী। কার-চিহ্নের কি-এর আগে <kbd>g</kbd> চাপলে পূর্ণ স্বরবর্ণ হয়, যেমন <kbd>g</kbd> <kbd>f</kbd> দিলে আ। দৃশ্যমান হসন্তের জন্য <kbd>g</kbd> দুবার চাপুন। |

প্রভাত ও ইউনিজয়ে:

- ইউনিকোড ক্রমে লেখা হয়, অর্থাৎ ব্যঞ্জনবর্ণের পরে কার: কি লিখতে আগে ক, তারপর
  ি, যদিও ি আগে দেখা যায়।
- কি-গুলো US কিবোর্ডের অবস্থান অনুযায়ী পড়া হয়, তাই পাশাপাশি একটি US (ABC)
  কিবোর্ড লেআউট রাখুন।
- Option (AltGr) লেয়ার এখনও যোগ করা হয়নি। ইউনিজয়ে এর মধ্যে পড়ে ZWJ/ZWNJ এবং
  ্য / র‍্য শর্টকাট; পূর্ণ স্বরবর্ণ অবশ্য <kbd>g</kbd> দিয়েই পাওয়া যায়।
- Preferences-এর সাজেশন লিস্ট, ডিকশনারি ও Enter অপশন শুধু অভ্র ফোনেটিকে
  প্রযোজ্য; ফিক্সড লেআউট বেছে নিলে এগুলো ধূসর হয়ে যায়।

## ANSI (বিজয়) আউটপুট

ইউনিকোডের বদলে SutonnyMJ সহ অন্যান্য বিজয় ফন্টের পুরনো বিজয় এনকোডিংয়ে লিখতে
**Preferences… › Output as ANSI (Bijoy fonts)** চালু করুন। তিনটি লেআউটেই এটি
কাজ করে, আর রূপান্তর উইন্ডোজের অভ্র কিবোর্ডের মতোই। ডকুমেন্টে একটি বিজয় ফন্ট
সেট করুন, নইলে লেখা ইংরেজি অক্ষরের মতো দেখাবে।

<p align="center">
  <img src="docs/assets/screenshots/output-as-ansi.png" width="560" alt="Preferences উইন্ডোতে Keyboard Layout-এর নিচে Output as ANSI (Bijoy fonts) চেকবক্স">
</p>

- অভ্র ফোনেটিকে ক্যান্ডিডেট বার থেকে বেছে নেওয়া শব্দটি বসানোর সময়েই রূপান্তরিত
  হয়।
- প্রভাত ও ইউনিজয়ে যে শব্দটি লিখছেন সেটি আন্ডারলাইন করা থাকে, বিজয়েই দেখায়,
  যতক্ষণ না স্পেস, Return বা লেআউটের বাইরের অন্য কোনো কি চাপছেন। বিজয়ে কিছু কার
  ব্যঞ্জনবর্ণের আগে বসে, তাই পুরো শব্দ একসাথেই রূপান্তর করতে হয়।
  <kbd>Delete</kbd> চাপলে শেষ চাপা কি-টি মুছে যায়।

## সমর্থিত macOS সংস্করণ

অভ্র কিবোর্ড macOS 12 Monterey ও তার পরের সব সংস্করণে চলে, Apple silicon (M1,
M2, M3, M4 ও পরবর্তী) এবং Intel দুই ধরনের ম্যাকেই, একটিমাত্র ইউনিভার্সাল বিল্ড
থেকে।

| macOS | নাম | Apple silicon | Intel |
| --- | --- | --- | --- |
| macOS 27 | Golden Gate | ✅ | — |
| macOS 26 | Tahoe | ✅ | ✅ |
| macOS 15 | Sequoia | ✅ | ✅ |
| macOS 14 | Sonoma | ✅ | ✅ |
| macOS 13 | Ventura | ✅ | ✅ |
| macOS 12 | Monterey | ✅ | ✅ |

macOS 27 Golden Gate আর Intel ম্যাকে চলে না; Intel ম্যাকে অভ্র কিবোর্ড macOS 26
Tahoe পর্যন্ত কাজ করে। macOS 11 Big Sur ও তার আগের সংস্করণ সমর্থিত নয়।

## ইনস্টলেশন

### পুরনো সংস্করণ সরানো

> [!IMPORTANT]
> আগে মূল iAvro (বান্ডল আইডেন্টিফায়ার
> `com.omicronlab.inputmethod.AvroKeyboard`) ইনস্টল করা থাকলে প্রথমে সেটি
> সরিয়ে ফেলুন। নইলে ইনপুট মেনুতে দুটি **Avro Keyboard** দেখাবে এবং macOS
> হয়তো পুরনোটিই চালু করতে থাকবে।

1. **System Settings › Keyboard › Input Sources › Edit…** খুলে তালিকা থেকে
   **Avro Keyboard** সরিয়ে দিন।
2. পুরনো অ্যাপটি মুছে ফেলুন। এটি নিচের কোনো একটি ফোল্ডারে থাকে (Finder-এ
   <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>G</kbd> চেপে পাথটি পেস্ট করুন):

   ```sh
   rm -rf ~/Library/Input\ Methods/Avro\ Keyboard.app
   sudo rm -rf /Library/Input\ Methods/Avro\ Keyboard.app
   ```

3. লগ আউট করে আবার লগ ইন করুন, তারপর নিচের নিয়মে নতুন সংস্করণ ইনস্টল করুন।

> [!NOTE]
> পুরনো সংস্করণের ব্যক্তিগত ডিকশনারি ও সেটিংস নতুনটিতে আসে না; সেগুলো পুরনো
> বান্ডল আইডেন্টিফায়ারের অধীনে সংরক্ষিত ছিল।

### Homebrew

```sh
brew install --cask aminulbd/tap/avro
```

এটি `Avro Keyboard.app` কে `~/Library/Input Methods`-এ ইনস্টল করে। ইনস্টলের পর
মেনু বারের ইনপুট মেনু থেকে এটি বেছে নিন।

| কাজ | কমান্ড |
| --- | --- |
| আপগ্রেড | `brew upgrade --cask avro` |
| আনইনস্টল | `brew uninstall --cask avro` |

### ম্যানুয়ালি

1. [Releases](https://github.com/AminulBD/iAvro/releases) পেজ থেকে
   `Avro-Keyboard-universal.dmg` ডাউনলোড করুন, অথবা আপনার ম্যাকের জন্য
   `apple-silicon` / `intel` বিল্ড।
2. DMG খুলে **Avro Keyboard**-এ ডাবল-ক্লিক করে **Install** চাপুন। এটি
   `~/Library/Input Methods`-এ কপি হয়ে আপনার ইনপুট সোর্সে যুক্ত হবে।
3. মেনু বারের ইনপুট মেনু থেকে এটি বেছে নিন।

> [!TIP]
> সব ইউজারের জন্য ইনস্টল করতে চাইলে অ্যাপটি নিজে `/Library/Input Methods`-এ
> কপি করুন, তারপর লগ আউট করে আবার লগ ইন করুন।

ইনপুট মেনুতে না দেখালে লগ আউট করে আবার লগ ইন করুন, তারপর
**System Settings › Keyboard › Input Sources › Edit… › +** খুলে
**Bangla › Avro Keyboard** বেছে **Add** চাপুন। macOS 12-এ একই তালিকা পাবেন
**System Preferences › Keyboard › Input Sources**-এ।

<p align="center">
  <img src="docs/assets/screenshots/input-method-macos.png" width="49%" alt="macOS 13 ও পরবর্তীতে System Settings-এর Input Sources-এ Avro Keyboard">
  <img src="docs/assets/screenshots/input-method-legacy-macos.png" width="49%" alt="macOS 12-এ System Preferences-এর Input Sources-এ Avro Keyboard">
</p>
<p align="center"><sub>macOS 13 ও পরবর্তী (বাঁয়ে) এবং macOS 12 (ডানে)-এ Input Sources</sub></p>

## বিল্ড করা

Xcode-এ `AvroKeyboard.xcodeproj` খুলে **Avro Keyboard** স্কিম বিল্ড করুন, অথবা
কমান্ড লাইন থেকে:

```sh
xcodebuild -project AvroKeyboard.xcodeproj \
  -scheme "Avro Keyboard" \
  -configuration Release \
  -derivedDataPath build
```

- **প্রয়োজন:** Xcode 16+, macOS 12.0+
- **ডিপেন্ডেন্সি:** নেই; SQLite আসে সিস্টেমের `libsqlite3` থেকে
- **আউটপুট:** `build/Build/Products/Release/Avro Keyboard.app`
- **বান্ডল আইডেন্টিফায়ার:** `app.aminul.inputmethod.AvroKeyboard`

## কন্টিনিউয়াস ইন্টিগ্রেশন

`v` দিয়ে শুরু হওয়া কোনো ট্যাগ পুশ করলে, অথবা Actions ট্যাব থেকে **Build**
ওয়ার্কফ্লো নিজে চালালে Apple Silicon (`arm64`), Intel (`x86_64`) ও ইউনিভার্সাল
বাইনারির Release বিল্ড তৈরি হয়। প্রতিটি ওয়ার্কফ্লো আর্টিফ্যাক্ট হিসেবে আপলোড
হয়: একটি `.dmg` ইনস্টলার ও অ্যাপের একটি `.zip`।

### রিলিজ

রিলিজ প্রকাশ করতে `v` দিয়ে শুরু হওয়া একটি ট্যাগ পুশ করুন:

```sh
git tag v1.6.0
git push origin v1.6.0
```

তিনটি বিল্ড শেষ হলে ওই ট্যাগের জন্য একটি GitHub রিলিজ তৈরি হয়, DMG ও zip
ফাইলসহ এবং স্বয়ংক্রিয়ভাবে তৈরি রিলিজ নোটসহ।

### সাইনিং ও নোটারাইজেশন

নিচের রিপোজিটরি সিক্রেটগুলো সেট করা থাকলে CI আপনার Developer ID সার্টিফিকেট
দিয়ে অ্যাপ সাইন করে, নোটারাইজেশনের জন্য Apple-এ পাঠায় এবং আপলোডের আগে টিকিট
স্টেপল করে।

> [!WARNING]
> এই সিক্রেটগুলো ছাড়া অ্যাপটি ad-hoc সাইন হয়, এবং অন্য ম্যাকে Gatekeeper
> এটি চালু হতে দেবে না।

| সিক্রেট | মান |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | আপনার **Developer ID Application** সার্টিফিকেটের (প্রাইভেট কি সহ) `.p12` এক্সপোর্টের Base64: `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` এক্সপোর্টের সময় দেওয়া পাসওয়ার্ড |
| `APPLE_TEAM_ID` | <https://developer.apple.com/account> থেকে ১০ অক্ষরের Team ID |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API কি-এর Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API keys পেজে দেখানো Issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | ডাউনলোড করা `AuthKey_XXXXXXXXXX.p8` ফাইলের পুরো কনটেন্ট |

API কি তৈরি করতে **App Store Connect › Users and Access › Integrations ›
App Store Connect API › Team Keys › +**-এ গিয়ে **Developer** (বা তার উপরের)
রোল বেছে নিন।

> [!NOTE]
> `.p8` ফাইলটি কেবল একবারই ডাউনলোড করা যায়।

## লাইসেন্স

ম্যাকের জন্য অভ্র কিবোর্ড [Mozilla Public License 1.1](LICENSE)-এর অধীনে
লাইসেন্সকৃত। Copyright © 2026 OmicronLab. সর্বস্বত্ব সংরক্ষিত।
