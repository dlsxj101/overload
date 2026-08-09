# GPT Sites 배포 메모

G0에서 Cloudflare Pages 대신 사용자가 승인한 GPT Sites 공개 배포 프로젝트의
식별자를 보관한다. 비밀값은 저장하지 않는다.

- 공개 URL: https://overload-game-g0.limewater.chatgpt.site

배포 소스는 Godot `Web` release export를 제공하는 얇은 vinext 래퍼다. 루트
경로는 `/game/index.html`로 이동한다. Sites의 파일당 25MiB 제한을 넘는 원시
WASM 대신 Brotli q11 파일을 배포 소스에 보관하고, edge route가 이를
`Content-Encoding: br`로 직접 응답한다. 브라우저가 복원한 39,513,091바이트
WASM의 SHA-256은 로컬 원본과 일치해야 한다.
