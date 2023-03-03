
bash 스크립트 입니다.

calls와 call_all 함수를 다음의 스팩을 준수하여 만들어 주세요.

calls 함수는 인수를 정의합니다. 주로 함수를 담기위해 사용합니다.
함수를 이용하는 패턴은 이런 패턴입니다. LIST=calls 함수1 함수2 함수3 ...

call_all 함수는 들어온 모든 인수를 순차적으로 실행시킵니다.

함수를 이용하는 패턴은 이런 패턴입니다. 
- call_all 함수1, 함수2, 함수3, ...
- LIST="fn1 fn2 fn3" \n call_all $LIST

다음과 같이 코딩을 할 수 있도록 해야합니다.
script.sh 파일
```
install_tmux (){
  echo "Start the tmux installation."
  sudo apt install tmux
}

install_htop (){
  echo "Start the htop installation."
  sudo apt install htop
}

INSTALLS=calls
call_all $INSTALLS
```

실행
```
./script.sh
#tmux 를 설치를 시작합니다.
```