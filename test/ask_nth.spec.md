
bash 스크립트 입니다.
ask_num 함수를 다음의 스팩을 준수하여 만들어 주세요.

ask_num 함수는 질문 문항을 매우 짧고 쉽게 만들어 가독성 있게 case 문을 사용할수 있도록 합니다.
함수를 호출하는 패턴은 이런 패턴입니다. " ask_num 변수이름, 항목1, 항목2, 항목3, ... "
다음과 같이 코딩을 할 수 있도록 해야합니다.

script.sh 파일
```
local CHOICE
echo "what's your favorite color"
ask_num CHOICE "RED" "GREEN" "BLUE"
echo "You chose $CHOICE"
```

실행
```
./script.sh
what's your favorite color
1) RED
2) GREEN
3) BLUE
Enter your choice:
```

여기서 숫자 2를 입력후 엔터키를 입력하면 다음과 같이 출력됩니다.
```
./script.sh
what's your favorite color
1) RED
2) GREEN
3) BLUE
Enter your choice: 2
2
```