
bash 스크립트 입니다.
call_nth 함수를 다음의 스팩을 준수하여 만들어 주세요.

call_nth 함수는 case문 대체를 위해 만듭니다.
함수를 호출하는 패턴은 이런 패턴입니다. " call_nth 함수번호, 함수1, 함수2, 함수3, ... "
다음과 같이 코딩을 할 수 있도록 해야합니다.

script.sh 파일
```
install_tmux (){
  echo "You have installed tmux."
}

install_htop (){
  echo "You have installed htop."
}

call_nth 1 install_tmux install_htop
```

실행
```
$ ./script.sh
You have installed tmux.
```