<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,11,20&height=180&section=header&text=ZheeSign&fontSize=72&fontColor=ffffff&animation=fadeIn&fontAlignY=38" />

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&size=22&duration=3000&pause=1000&color=8A2BE2&center=true&vCenter=true&width=600&lines=Ứng+dụng+tự+ký+iOS+mạnh+mẽ;Việt+hóa+100%25+%F0%9F%87%BB%F0%9F%87%B3;Rebrand+từ+Ksign+%E2%80%A2+GPL-3.0)](https://github.com/zheedevVn/ZheeSign)

<br/>

[![Release](https://img.shields.io/github/v/release/zheedevVn/ZheeSign?label=Beta&style=for-the-badge&logo=apple&logoColor=white&color=8A2BE2)](https://github.com/zheedevVn/ZheeSign/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/zheedevVn/ZheeSign/beta.yml?label=Build&style=for-the-badge&logo=githubactions&logoColor=white&color=00D4FF)](https://github.com/zheedevVn/ZheeSign/actions)
[![License](https://img.shields.io/badge/License-GPL--3.0-ff69b4?style=for-the-badge&logo=gnu&logoColor=white)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/zheedevVn/ZheeSign/releases)

</div>

---

## ✨ Giới thiệu

**ZheeSign** là công cụ tự ký (sideload) ứng dụng iOS — được **Việt hóa hoàn toàn 100%**, rebrand với icon neon mới, và phát triển tiếp bởi **Hồ Đức Minh**.

> Tải bản mới nhất tại 👉 [**Releases**](https://github.com/zheedevVn/ZheeSign/releases)

## 🚀 Tính năng

| | |
|---|---|
| 📝 | **Tự ký IPA** bằng chứng chỉ của bạn (p12 + mobileprovision) |
| 💉 | **Tiêm tweak** (dylib/deb) vào ứng dụng |
| 📦 | Quản lý **nguồn tải**, **thư viện ứng dụng**, **chứng chỉ** |
| 🎨 | **Icon app tùy biến** — đổi icon ZheeSign theo phong cách riêng |
| 🌐 | **Máy chủ WebDAV / LocalDevVPN** tích hợp |
| 🇻🇳 | **Giao diện tiếng Việt 100%** — không còn chữ Trung |

## 📲 Cài đặt

1. Vào [**Releases**](https://github.com/zheedevVn/ZheeSign/releases) tải file `ZheeSign.ipa` mới nhất
2. Ký & cài bằng công cụ yêu thích (TrollStore, AltStore, Sideloadly, ESign...)
3. Mở app → thêm chứng chỉ → ký IPA → cài đặt. Xong! 🎉

> 💡 **Mẹo:** Vào *Cài đặt → Biểu tượng ứng dụng* để đổi icon neon Z cho ngầu.

## 🔨 Build từ source

Workflow [`.github/workflows/beta.yml`](.github/workflows/beta.yml) tự động build IPA trên macOS runner mỗi khi push lên `main`.

Build thủ công:

```bash
git clone https://github.com/zheedevVn/ZheeSign
cd ZheeSign
git submodule update --init --recursive
make   # IPA ra tại packages/ZheeSign.ipa
```

## 📜 Giấy phép & Nguồn gốc

ZheeSign là phần mềm tự do theo giấy phép **GNU General Public License v3.0** — xem file [LICENSE](LICENSE).

| Nguồn | Tác giả |
|---|---|
| [Ksign](https://github.com/vulnnull/Ksign) (bản Trung giản thể) | **vulnnull** |
| [Nyasami/Ksign](https://github.com/Nyasami/Ksign) | **Nyasami** |
| [Feather](https://github.com/khcrysalis/Feather) | **khcrysalis** |

Mọi bản phân phối của ZheeSign đều tuân thủ GPL-3.0: mã nguồn được công khai đầy đủ tại repo này.

## ©️ Bản quyền

- © 2026 **Hồ Đức Minh** ([zheedevVn](https://github.com/zheedevVn)) — các thay đổi trong bản fork này
- © Các tác giả gốc (vulnnull, Nyasami, khcrysalis) — mã nguồn gốc, theo GPL-3.0

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,11,20&height=120&section=footer" />

**⭐ Nếu thấy hữu ích, cho mình 1 star nhé! ⭐**

</div>
