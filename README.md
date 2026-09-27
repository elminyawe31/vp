# VP — Browser-Based Linux VPS

A lightweight Linux desktop environment that runs inside a Docker container and can be accessed directly from a web browser.

VP combines **Selkies** for browser-based desktop streaming with **Cloudflare Quick Tunnel** for public access without requiring a manually configured reverse proxy or a permanent public IP.

The goal is simple: start the container, wait for the tunnel URL, and open the desktop from anywhere.

<p align="center">
  <a href="#العربية">🇪🇬 العربية</a>
  &nbsp;&nbsp;&nbsp;
  <a href="#english">🇺🇸 ENGLISH</a>
</p>

---

<a id="english"></a>

# 🇺🇸 English

## Overview

VP turns a Docker container into a remotely accessible Linux desktop.

The container provides:

* A complete Linux graphical desktop
* Browser-based remote access through Selkies
* WebSocket desktop streaming
* Audio support
* Keyboard and mouse input
* Clipboard support
* Gamepad support
* Automatic Cloudflare Quick Tunnel
* A public `trycloudflare.com` URL printed directly to the container logs
* Docker and Railway deployment support

The project is designed to be simple to deploy and easy to reproduce.

---

## How It Works

The project is built around two main components.

### Selkies

Selkies provides the browser-based Linux desktop.

It runs the graphical session inside the container and streams the desktop to a web browser using its WebSocket transport.

### Cloudflare Quick Tunnel

`cloudflared` creates a temporary public tunnel from the container to the local Selkies service.

The tunnel points to:

```text
http://127.0.0.1:8080
```

Once Cloudflare provides a public address, VP detects the generated `trycloudflare.com` URL and prints it to the container logs.

The result looks like:

```text
==========================================================
           CLOUDFLARE TUNNEL IS READY
==========================================================

  URL: https://example-name.trycloudflare.com

  Selkies: http://127.0.0.1:8080

  STATUS: ONLINE

==========================================================
```

---

## Features

### 🖥️ Browser-Based Linux Desktop

Access the containerized Linux desktop directly from a modern browser without installing a traditional remote desktop client.

### 🌐 Automatic Public URL

Cloudflare Quick Tunnel is started automatically and exposes the local Selkies service through a public HTTPS URL.

### 🐳 Fully Containerized

The entire environment runs inside Docker, making the setup reproducible across compatible environments.

### ⚡ WebSocket Streaming

VP uses Selkies' WebSocket transport for interactive desktop streaming.

### 🔊 Audio

The underlying Selkies desktop environment includes audio support for browser-based sessions.

### 🎮 Input Support

Keyboard, mouse, clipboard and virtual gamepad input are supported by the desktop streaming layer.

### 🔄 Automatic Tunnel Restart

The Cloudflare process is designed to restart if the tunnel exits, allowing the container to recover without manually restarting the session.

### ☁️ Railway Friendly

The project can be deployed as a Docker application on platforms such as Railway.

---

## Requirements

You need:

* Docker
* Internet access
* A machine or platform capable of running Linux containers
* Sufficient shared memory for the desktop browser session

For local Docker usage, the recommended shared memory size is:

```text
2 GB
```

---

## Quick Start

The easiest way to run the published image is:

```bash
docker pull ghcr.io/elminyawe31/vp:latest && docker run --rm --shm-size=2g -p 8080:8080 ghcr.io/elminyawe31/vp:latest
```

The command pulls the latest image and starts the container immediately after the image is available.

Wait until the logs show:

```text
CLOUDFLARE TUNNEL IS READY
```

Then open the displayed `trycloudflare.com` URL in your browser.

---

## Docker Image

The published image is available through GitHub Container Registry:

```text
ghcr.io/elminyawe31/vp:latest
```

You can pull it separately with:

```bash
docker pull ghcr.io/elminyawe31/vp:latest
```

Then start it with:

```bash
docker run --rm --shm-size=2g -p 8080:8080 ghcr.io/elminyawe31/vp:latest
```

---

## Building From Source

Clone the repository:

```bash
git clone https://github.com/elminyawe31/vp.git
cd vp
```

Build the image:

```bash
docker build -t vp .
```

Run it:

```bash
docker run --rm --shm-size=2g -p 8080:8080 vp
```

Once the container starts, the Cloudflare public URL will appear in the logs.

---

## Configuration

The container is configured around port `8080`.

The main environment variables include:

| Variable               |        Value | Purpose                                              |
| ---------------------- | -----------: | ---------------------------------------------------- |
| `PORT`                 |       `8080` | Container service port                               |
| `SELKIES_PORT`         |       `8080` | Selkies web server port                              |
| `SELKIES_MODE`         | `websockets` | Selkies transport mode                               |
| `SELKIES_ENABLE_HTTPS` |      `false` | HTTPS is handled externally by the Cloudflare tunnel |
| `SELKIES_WAYLAND`      |      `false` | Uses the X11 desktop backend                         |
| `PASSWD`               | configurable | Desktop authentication password                      |

For production or shared environments, change the default password before exposing the session publicly.

---

## Deployment on Railway

VP can be deployed as a Docker application on Railway.

The repository includes a `railway.toml` configuration that tells Railway to build the project using the root `Dockerfile`.

The deployment configuration also enables automatic restarts when the container exits unexpectedly.

After deployment, the container logs expose the generated Cloudflare URL.

---

## Use Cases

VP can be useful when you need a temporary Linux graphical environment that can be accessed remotely from a browser.

Examples include:

* Temporary cloud desktops
* Browser-accessible Linux environments
* Remote development environments
* Testing Linux GUI applications
* Running desktop applications inside isolated containers
* Demonstrations and experiments
* Temporary environments on cloud platforms
* Remote GUI sessions for development and testing

The project is especially useful when you want to avoid configuring a traditional VPS desktop stack with a separate VNC server, reverse proxy, TLS certificate, and public networking setup.

---

## Architecture

```text
                     Internet
                         │
                         ▼
              Cloudflare Quick Tunnel
                         │
                         ▼
              ┌─────────────────────┐
              │       Docker        │
              │                     │
              │     cloudflared     │
              │          │          │
              │          ▼          │
              │   localhost:8080    │
              │          │          │
              │          ▼          │
              │        Selkies      │
              │          │          │
              │          ▼          │
              │    Linux Desktop    │
              │                     │
              └─────────────────────┘
                         │
                         ▼
                    Web Browser
```

---

## Base Image

VP is built on the Selkies desktop container:

```text
ghcr.io/selkies-project/selkies/desktop:main-ubuntu26.04
```

This provides the underlying Linux desktop, graphical session, browser streaming stack and supporting desktop services.

VP adds Cloudflare `cloudflared` on top of the base image to provide automatic public access.

---

## Project Structure

```text
vp/
├── Dockerfile
├── cloudflared-run
├── cloudflared-start.sh
└── railway.toml
```

### `Dockerfile`

Builds the VP container and installs `cloudflared` on top of the Selkies desktop image.

### `cloudflared-run`

Handles the Cloudflare Quick Tunnel process and detects the generated public URL.

### `cloudflared-start.sh`

Provides the startup flow used to launch Cloudflare and the Selkies desktop session.

### `railway.toml`

Contains the Railway build and deployment configuration.

---

## Security Notes

Cloudflare Quick Tunnels are intended for temporary and development-oriented access.

The generated public URL is not a permanent hostname and can change when the tunnel is restarted.

Do not treat the public tunnel as a replacement for a properly secured production remote-access architecture.

If the desktop is exposed publicly, use a strong password and avoid storing sensitive information inside temporary sessions.

---

## Why VP?

The project focuses on one thing:

> **A Linux desktop that you can start with Docker and reach from a browser with almost no networking setup.**

Instead of manually configuring:

* a Linux desktop
* a remote desktop server
* a reverse proxy
* TLS
* port forwarding
* a public hostname

VP puts the main pieces together in one container workflow.

Start the image, wait for the tunnel, open the URL.

---

## Credits

VP is built on top of the excellent open-source [Selkies](https://github.com/selkies-project/selkies) project.

Cloudflare Quick Tunnel is provided by [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/).

---

## Author

**ELMINYAWE**

GitHub: [@elminyawe31](https://github.com/elminyawe31)

---

<a id="العربية"></a>

# 🇪🇬 العربية

## ما هو VP؟

**VP** هو مشروع يحوّل حاوية Docker إلى **سطح مكتب Linux كامل يمكن الوصول إليه من خلال متصفح الإنترنت**.

الفكرة الأساسية بسيطة:

بدل ما تقوم بإعداد VPS، وتثبيت سطح مكتب، وإعداد VNC أو Remote Desktop، وتجهيز Reverse Proxy وشهادة SSL وفتح المنافذ، المشروع يجمع الأجزاء الأساسية معًا داخل Container واحدة.

عند تشغيل المشروع، يتم تشغيل سطح مكتب Linux باستخدام **Selkies**، ثم يتم إنشاء **Cloudflare Quick Tunnel** تلقائيًا للوصول إلى سطح المكتب من الإنترنت.

وفي النهاية يظهر لك رابط مثل:

```text
https://example-name.trycloudflare.com
```

تفتح الرابط من المتصفح وتدخل إلى سطح المكتب مباشرة.

---

## 💡 فكرة المشروع

يمكن تلخيص المشروع في الخطوات التالية:

```text
Docker Container
       │
       ▼
 Linux Desktop
       │
       ▼
    Selkies
       │
       ▼
localhost:8080
       │
       ▼
Cloudflare Tunnel
       │
       ▼
Public HTTPS URL
       │
       ▼
    Browser
```

بمعنى آخر، **VP يأخذ بيئة Linux رسومية داخل Docker ويجعلها متاحة من خلال المتصفح بدون الحاجة إلى إعداد شبكة معقدة.**

---

## ✨ مميزات المشروع

### 🖥️ سطح مكتب Linux من المتصفح

يمكنك تشغيل بيئة Linux رسومية كاملة والوصول إليها من خلال المتصفح.

لا تحتاج إلى تثبيت برنامج Remote Desktop تقليدي على جهازك.

### 🌐 رابط عام تلقائي

المشروع يشغّل Cloudflare Quick Tunnel تلقائيًا.

بعد تشغيل الـContainer، يتم البحث عن الرابط الناتج وطباعة الرابط في الـlogs.

مثال:

```text
==========================================================
           CLOUDFLARE TUNNEL IS READY
==========================================================

  URL: https://example-name.trycloudflare.com

  Selkies: http://127.0.0.1:8080

  STATUS: ONLINE

==========================================================
```

### 🐳 يعمل بالكامل داخل Docker

كل البيئة تعمل داخل Container، مما يجعل تشغيل المشروع ونقله بين البيئات أسهل.

### ⚡ WebSocket Streaming

يستخدم المشروع Selkies مع WebSocket transport لبث سطح المكتب والتفاعل معه من المتصفح.

### 🔊 دعم الصوت

بيئة Selkies المستخدمة في المشروع توفر دعمًا للصوت أثناء جلسة سطح المكتب.

### 🎮 دعم أجهزة الإدخال

يدعم المشروع:

* Keyboard
* Mouse
* Clipboard
* Virtual Gamepads

### ☁️ مناسب للنشر على Railway

يمكن تشغيل المشروع باستخدام Docker على Railway، مع إعداد `railway.toml` الموجود في المشروع.

---

## 🚀 طريقة التشغيل

إذا كنت تريد استخدام النسخة المنشورة من المشروع، يمكنك تشغيل:

```bash
docker pull ghcr.io/elminyawe31/vp:latest && docker run --rm --shm-size=2g -p 8080:8080 ghcr.io/elminyawe31/vp:latest
```

الأمر يقوم بتحميل أحدث نسخة من المشروع ثم تشغيلها مباشرة.

بعد تشغيل الـContainer، انتظر حتى يظهر:

```text
CLOUDFLARE TUNNEL IS READY
```

ستجد بعدها رابط Cloudflare في الـlogs.

افتح الرابط في المتصفح، وستظهر لك جلسة سطح المكتب.

---

## 📦 تشغيل المشروع من المصدر

قم بتحميل المشروع:

```bash
git clone https://github.com/elminyawe31/vp.git
cd vp
```

ثم قم ببناء الـDocker image:

```bash
docker build -t vp .
```

وبعدها شغّل الـContainer:

```bash
docker run --rm --shm-size=2g -p 8080:8080 vp
```

بعد التشغيل سيظهر رابط Cloudflare في الـlogs.

---

## 🔧 الإعدادات

يعمل Selkies داخل المشروع على المنفذ:

```text
8080
```

ومن أهم المتغيرات المستخدمة:

| المتغير                |        القيمة | الوظيفة                                 |
| ---------------------- | ------------: | --------------------------------------- |
| `PORT`                 |        `8080` | منفذ الخدمة                             |
| `SELKIES_PORT`         |        `8080` | منفذ Selkies                            |
| `SELKIES_MODE`         |  `websockets` | طريقة نقل جلسة سطح المكتب               |
| `SELKIES_ENABLE_HTTPS` |       `false` | HTTPS يتم التعامل معه بواسطة Cloudflare |
| `SELKIES_WAYLAND`      |       `false` | استخدام X11                             |
| `PASSWD`               | قابلة للتغيير | كلمة مرور سطح المكتب                    |

إذا كنت ستستخدم المشروع في بيئة مشتركة أو ستعرضه للعامة، استخدم كلمة مرور قوية بدل كلمة المرور الافتراضية.

---

## 🎯 أين يمكن استخدام VP؟

المشروع مناسب لأي حالة تحتاج فيها إلى **بيئة Linux رسومية مؤقتة يمكن الوصول إليها من المتصفح**.

من أمثلة الاستخدام:

* تشغيل Linux Desktop على سيرفر سحابي
* بيئات تطوير مؤقتة
* اختبار برامج Linux التي تحتاج إلى واجهة رسومية
* تشغيل تطبيقات GUI داخل Containers
* التجارب والمشاريع التعليمية
* عمل Demo لتطبيقات Linux
* بيئات اختبار مؤقتة
* الوصول إلى سطح مكتب Linux من جهاز لا يحتوي على Linux
* تشغيل بيئة رسومية على منصات مثل Railway

---

## 🔐 هل VP عبارة عن VPS حقيقي؟

ليس VPS بالمعنى التقليدي.

VP هو **Linux desktop environment داخل Docker container** مع إمكانية الوصول إليه من المتصفح.

هذا يجعله مناسبًا للبيئات المؤقتة والتجارب والتطوير والاختبار.

أما إذا كنت تحتاج إلى سيرفر دائم بموارد مخصصة وتخزين دائم واسم نطاق ثابت وإعدادات شبكة وتحكم كامل بالنظام، فـVPS التقليدي سيكون نموذجًا مختلفًا.

---

## 🌍 لماذا Cloudflare؟

بدل أن تحتاج إلى:

* فتح Port على الراوتر
* الحصول على Public IP ثابت
* إعداد Reverse Proxy
* إعداد SSL
* شراء أو إعداد Domain
* ضبط قواعد Firewall للوصول الخارجي

يقوم Cloudflare Quick Tunnel بإنشاء Tunnel مؤقت بين الـContainer وخدمة Cloudflare.

وبمجرد إنشاء الـTunnel، يحصل المشروع على رابط `trycloudflare.com` يمكن استخدامه للوصول إلى Selkies.

---

## 🏗️ بنية المشروع

```text
                     الإنترنت
                         │
                         ▼
              Cloudflare Quick Tunnel
                         │
                         ▼
              ┌─────────────────────┐
              │       Docker        │
              │                     │
              │     cloudflared     │
              │          │          │
              │          ▼          │
              │   localhost:8080    │
              │          │          │
              │          ▼          │
              │        Selkies      │
              │          │          │
              │          ▼          │
              │    Linux Desktop    │
              │                     │
              └─────────────────────┘
                         │
                         ▼
                    Web Browser
```

---

## 📁 ملفات المشروع

```text
vp/
├── Dockerfile
├── cloudflared-run
├── cloudflared-start.sh
└── railway.toml
```

### Dockerfile

مسؤول عن بناء الـContainer وإضافة `cloudflared` إلى بيئة Selkies.

### cloudflared-run

مسؤول عن تشغيل Cloudflare Quick Tunnel والتعامل مع الرابط الناتج.

### cloudflared-start.sh

يحتوي على منطق بدء خدمات Cloudflare وبيئة سطح المكتب.

### railway.toml

يحتوي على إعدادات بناء ونشر المشروع على Railway.

---

## ⚠️ ملاحظات أمنية

رابط Cloudflare Quick Tunnel هو رابط مؤقت، وليس Domain ثابتًا للمشروع.

يمكن أن يتغير الرابط عند إعادة تشغيل الـTunnel.

لذلك يُفضّل استخدام VP للبيئات المؤقتة والتطوير والاختبار، وعدم التعامل مع Quick Tunnel كبديل عن بنية Remote Access مخصصة للـProduction.

إذا قمت بتعريض سطح المكتب للإنترنت، استخدم كلمة مرور قوية ولا تخزن بيانات حساسة داخل جلسة مؤقتة.

---

## ❤️ لماذا تم إنشاء VP؟

الهدف من المشروع هو جعل تشغيل Linux Desktop عن بُعد أمرًا بسيطًا قدر الإمكان.

بدلًا من قضاء وقت في إعداد:

```text
Linux Desktop
      +
Remote Desktop Server
      +
Reverse Proxy
      +
SSL
      +
Port Forwarding
      +
Public Network
```

يضع VP الأجزاء الأساسية في workflow واحد:

```text
Run
  ↓
Docker
  ↓
Selkies
  ↓
Cloudflare Tunnel
  ↓
Open the URL
```

**شغّل الـContainer، خذ الرابط، وافتح سطح المكتب.**

---

## 🙏 Credits

يعتمد VP على مشروع **Selkies** مفتوح المصدر.

* Selkies: https://github.com/selkies-project/selkies
* Cloudflare Tunnel: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

---

## 👨‍💻 المطور

**ELMINYAWE**

GitHub: https://github.com/elminyawe31

---

<p align="center">
  <a href="#english">⬆️ Back to English</a>
</p>
