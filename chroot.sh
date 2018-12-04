#!/bin/bash
# TODO: good codebase, need parameters and make a more generic tool
#Memo :https://wiki.alpinelinux.org/wiki/Installing_Alpine_Linux_in_a_chroot
#vte-256color
#kitty

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

#Get last version of apk-tools-static
content=$(wget "https://pkgs.alpinelinux.org/package/edge/main/x86/apk-tools-static" -O - | grep "Flag this package out of date" | sed 's|</a>||;s|.*>||')
echo $content
if [$content = ""];then
    echo $content
    content=$(wget "https://pkgs.alpinelinux.org/package/edge/main/x86/apk-tools-static" -O - | grep "aria-label=\"Flagged:" | sed 's|</a>||;s|.*>||')
    echo $content
fi


APKPKT=apk-tools-static-$content.apk
mirror=http://dl-cdn.alpinelinux.org/alpine/
MAINREP=$(pwd)
CHROOT=$MAINREP/chroot
PACKAGES="vim zsh curl"
POSTPACKAGES="alpine-sdk git openssh openssl openssl-dev crystal curl tmux"
chroot_dir="$(pwd)"


chroot_install(){
    mkdir -p $CHROOT
    cd ${MAINREP}/

    if [ -f ${APKPKT} ]; then
        echo "apk already downloaded"
    else
        wget ${mirror}/edge/main/`uname -p`/${APKPKT}
        tar -xzf ${APKPKT}
    fi

    ${MAINREP}/sbin/apk.static -X ${mirror}/latest-stable/main -U --allow-untrusted --root ${CHROOT} --initdb add alpine-base $PACKAGES
    cp /etc/resolv.conf $CHROOT/etc/
    #cp -r ~/.zsh* ~/.vim* ${CHROOT}/root
    #echo export PS1=\"\(chroot\) \$PS1\"  >> ${CHROOT}/root/.zshrc

    cat << END >> $CHROOT/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
END

    chroot $CHROOT apk update
    sed -i "s/ash/zsh/" "${CHROOT}/etc/passwd"
    sed -i '1s|^|set shell=/bin/zsh\n|' "${CHROOT}/etc/vim/vimrc"
}

chroot_mount(){
#    mount -t proc /proc ${CHROOT}/proc/
#    mount -o bind /sys  ${CHROOT}/sys/
    mount -o bind /dev  ${CHROOT}/dev/
}

chroot_post(){
    ${MAINREP}/sbin/apk.static --root ${CHROOT} add $POSTPACKAGES
    # chroot ${CHROOT} /bin/zsh -l "apk update && apk upgrade && apk add $POSTPACKAGES"
}

chroot_vim_post(){
chroot ${CHROOT} apk add git
#Vim Pluging management tool
    cat << END >> $CHROOT/etc/vim/vimrc
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
END


#Vim auto load pluging
touch ${CHROOT}/root/.vimrc
cat << END >>${CHROOT}/root/.vimrc
call plug#begin('~/.vim/plugged')

Plug 'https://github.com/rhysd/vim-crystal'
Plug 'https://github.com/leafo/moonscript-vim'
Plug 'https://github.com/tomasr/molokai'

call plug#end()
END

echo -e  " run in vim > :PlugInstall"

}

chroot_env(){
    HOME=/root \
        chroot ${CHROOT} /bin/zsh -lm
}

ask(){
    echo -en "$1? [YyNn] (n): "
    read V ; echo $V | grep "[Yy]" >/dev/null
    if [ $? -eq 0 ] ; then
        echo -en "doing $1..." ; $1
    else
        echo "not doing $1"
    fi
}

ask chroot_install
ask chroot_mount
ask chroot_post
ask chroot_vim_post
ask chroot_env

