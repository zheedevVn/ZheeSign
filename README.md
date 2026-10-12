# ZheeSign

Ứng dụng tự ký iOS — bản fork Việt hóa của Ksign, phát triển bởi **Hồ Đức Minh (zheedevVn)**.

Tải bản mới nhất tại [Releases](https://github.com/zheedevVn/ZheeSign/releases).

## Giới thiệu

ZheeSign là công cụ tự ký (sideload) ứng dụng iOS, được Việt hóa hoàn chỉnh và rebrand từ Ksign.

## Giấy phép & Nguồn gốc

ZheeSign là phần mềm tự do theo giấy phép **GNU General Public License v3.0** — xem file [LICENSE](LICENSE).

- Dựa trên [Ksign](https://github.com/vulnnull/Ksign) của **vulnnull** (bản Trung giản thể)
- Gốc từ [Nyasami/Ksign](https://github.com/Nyasami/Ksign) của **Nyasami**
- Kế thừa từ [Feather](https://github.com/khcrysalis/Feather) của **khcrysalis**

Mọi bản phân phối của ZheeSign đều tuân thủ GPL-3.0: mã nguồn được công khai đầy đủ tại repo này.

## Build

Workflow `.github/workflows/beta.yml` tự động build IPA trên macOS runner mỗi khi push lên `main`:

```bash
make   # build thủ công, IPA ra tại packages/ZheeSign.ipa
```

## Bản quyền

© 2026 Hồ Đức Minh (zheedevVn) — các thay đổi trong bản fork này.
© Các tác giả gốc (vulnnull, Nyasami, khcrysalis) — mã nguồn gốc, theo GPL-3.0.
