echo "ACTIVATE CUSTOM CONFIG ($HOME/config/unix-source/)"

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

echo -e "Your pwd => $PWD\nENTER COMMAND\n0!) setup or resetup\n0) reload your all config \n1) git user \n9) local tm_properties"
read selected

case "$selected" in
    "0!")
        local UTIME=$(date +%s)

        if [ -d $HOME/config/unix-source ]
        then
            cp -rf "$HOME/config/unix-source" "$HOME/config/unix-source.removed.$UTIME"
            rm -rf "$HOME/config/unix-source"
            echo "removed $HOME/config/unix-source"
        fi
        
        cp -rf "$HOME/config/unix-source.default" "$HOME/config/unix-source"
        echo "copyed $HOME/config/unix-source.default to $HOME/config/unix-source"
        
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
    "9")
        if [ ! -h $PWD/.tm_properties ]
        then
            touch .tm_properties
        fi
        
        read -p "usesofttab?[true/false]" softtab
        read -p "tabsize?(2/4/...)" tabsize
        
        if [ $softtab ]
        then
            echo "softWrap=$softtab" >> "$PWD/.tm_properties"
            echo "softTabs=$softtab" >> "$PWD/.tm_properties"
        fi
        
        if [ $tabsize ]
        then
            echo "tabSize=$tabsize" >> "$PWD/.tm_properties"
        fi
        
    ;;
esac

}

# alias
alias mfzf='mate $(fzf)'
alias vfzf='vim $(fzf)'
