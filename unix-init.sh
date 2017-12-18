echo "ACTIVATE CUSTOM UNIX CONFIG"

LINK_TARGET_FILES=".gitconfig .vimrc .tmux.conf .tm_properties"

function config {

echo -e "1.git user"
read selected

if [ $selected -eq "1" ]
then
    echo "user email"
    read email
    echo "user name"
    read name
    
    git config user.name "$name"
    git config user.email "$email"
fi

}

