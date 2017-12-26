echo "ACTIVATE CUSTOM UNIX CONFIG ($HOME/config/unix-source/)"

# setting
LINK_TARGET_FILES=".gitconfig .vimrc .tmux.conf .tm_properties"

function configbootstrap {

# 미리 정의해놓은 설정파일들 링크 처리
for FILE_ITEM in $LINK_TARGET_FILES
do

if [ ! -h $HOME/$FILE_ITEM ]
then
echo "link file $HOME/config/unix-source/$FILE_ITEM"
ln -sf $HOME/config/unix-source/$FILE_ITEM $HOME/$FILE_ITEM
fi
done

}


# command
function config {

echo -e "ENTER COMMAND\n[0!] remove your all config\n[0] reload your all config \n[1] git user"
read selected

case "$selected" in
    "0!")
        for FILE_ITEM in $LINK_TARGET_FILES
        do
            rm $HOME/$FILE_ITEM
            echo "rm $FILE_ITEM"
        done
        configbootstrap
    ;;
    "0")
        source "$HOME/config/unix-init.sh"
    ;;
    "1")
        echo "user email"
        read email
        echo "user name"
        read name

        git config user.name "$name"
        git config user.email "$email"
    ;;
esac

}

# alias
alias mfzf='mate $(fzf)'
alias vfzf='vim $(fzf)'
