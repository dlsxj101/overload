# Black Han Sans 서브셋 재생성

웹 빌드에는 `BlackHanSans-Regular.ttf` 서브셋만 넣는다. OFL 원본은
`fonts/source/BlackHanSans-Regular.full.ttf`에 보관하며 export에서 제외한다.

UI 문자열을 추가하거나 수정한 뒤 프로젝트 루트에서 다음을 실행한다.

```bash
python -m pip install fonttools
python tools/subset_font.py
```

스크립트는 런타임 `.gd`, `.tscn`, `.tres`, `project.godot`의 문자열 리터럴과
인쇄 가능한 ASCII 전체를 수집해 폰트를 다시 만든다. 실행 뒤에는 반드시 웹
release export를 만들고 F1·F2 패널 및 게임 화면에서 깨진 글자가 없는지 확인한다.
