#!/bin/bash -e
{ # this ensures the entire script is downloaded

JABBA_HOME=${JABBA_HOME:-$JABBA_DIR} # JABBA_DIR is here for backward-compatibility
JABBA_VERSION=${JABBA_VERSION:-latest}

if [ "$JABBA_HOME" == "" ] || [ "$JABBA_HOME" == "$HOME/.jabba" ]; then
    JABBA_HOME=$HOME/.jabba
    JABBA_HOME_TO_EXPORT=\$HOME/.jabba
else
    JABBA_HOME_TO_EXPORT=$JABBA_HOME
fi

# curl looks for HTTPS_PROXY while wget for https_proxy
https_proxy=${https_proxy:-$HTTPS_PROXY}
HTTPS_PROXY=${HTTPS_PROXY:-$https_proxy}

if [ "$JABBA_GET" == "" ]; then
    if [ -z "$(curl -V 1>/dev/null)" ]; then
        JABBA_GET="curl -sL"
    else
        JABBA_GET="wget -qO-"
    fi
fi

if [ "$JABBA_VERSION" == "latest" ]; then
    # resolving "latest" to an actual tag
    JABBA_VERSION=$($JABBA_GET https://shyiko.github.com/jabba/latest)
fi

# http://semver.org/spec/v2.0.0.html
if [[ ! "$JABBA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.+-]+)?$ ]]; then
    echo "'$JABBA_VERSION' is not a valid version."
    exit 1
fi

case "$OSTYPE" in
    darwin*)
    BINARY_URL=https://github.com/shyiko/jabba/releases/download/${JABBA_VERSION}/jabba-${JABBA_VERSION}-darwin-amd64
    ;;
    linux*)
    case "$(uname -m)" in
        arm*|aarch*)
        if [ `getconf LONG_BIT` = "64" ]; then OSARCH=arm64; else OSARCH=arm; fi
        ;;
        *)
        if [ `getconf LONG_BIT` = "64" ]; then OSARCH=amd64; else OSARCH=386; fi
        ;;
    esac
    BINARY_URL=https://github.com/shyiko/jabba/releases/download/${JABBA_VERSION}/jabba-${JABBA_VERSION}-linux-${OSARCH}
    ;;
    *)
    echo "Unsupported OS $OSTYPE. If you believe this is an error -
please create a ticket at https://github.com/shyiko/jabba/issues."
    exit 1
    ;;
esac

echo "Installing v$JABBA_VERSION..."
echo

if [ ! -f "${JABBA_HOME}/bin/jabba" ]; then
    JABBA_SELF_DESTRUCT_AFTER_COMMAND="true"
fi

mkdir -p ${JABBA_HOME}/bin

if [ "$JABBA_MAKE_INSTALL" == "true" ]; then
    cp jabba ${JABBA_HOME}/bin
else
    $JABBA_GET ${BINARY_URL} > ${JABBA_HOME}/bin/jabba && chmod a+x ${JABBA_HOME}/bin/jabba
fi

if ! ${JABBA_HOME}/bin/jabba --version &>/dev/null; then
    echo "${JABBA_HOME}/bin/jabba does not appear to be a valid binary.

Check your Internet connection / proxy settings and try again.
If the problem persists - please create a ticket at https://github.com/shyiko/jabba/issues."
    exit 1
fi

if [ "$JABBA_COMMAND" != "" ]; then
    ${JABBA_HOME}/bin/jabba $JABBA_COMMAND
    if [ "$JABBA_SELF_DESTRUCT_AFTER_COMMAND" == "true" ]; then
        rm -f ${JABBA_HOME}/bin/jabba
        rmdir ${JABBA_HOME}/bin
        exit 0
    fi
fi

{
echo "# https://github.com/shyiko/jabba"
echo "# This file is indented to be \"sourced\" (i.e. \". ~/.jabba/jabba.sh\")"
echo ""
echo "export JABBA_HOME=\"$JABBA_HOME_TO_EXPORT\""
echo ""
echo "jabba() {"
echo "    local fd3=\$(mktemp /tmp/jabba-fd3.XXXXXX)"
echo "    (JABBA_SHELL_INTEGRATION=ON $JABBA_HOME_TO_EXPORT/bin/jabba \"\$@\" 3>| \${fd3})"
echo "    local exit_code=\$?"
echo "    eval \$(cat \${fd3})"
echo "    rm -f \${fd3}"
echo "    return \${exit_code}"
echo "}"
echo ""
echo "if [ ! -z \"\$(jabba alias default)\" ]; then"
echo "    jabba use default"
echo "fi"
} > ${JABBA_HOME}/jabba.sh

SOURCE_JABBA="\n[ -s \"$JABBA_HOME/jabba.sh\" ] && source \"$JABBA_HOME/jabba.sh\""

files=("$HOME/.bashrc")

if [ -f "$HOME/.bash_profile" ]; then
    files+=("$HOME/.bash_profile")
elif [ -f "$HOME/.bash_login" ]; then
    files+=("$HOME/.bash_login")
elif [ -f "$HOME/.profile" ]; then
    files+=("$HOME/.profile")
else
    files+=("$HOME/.bash_profile")
fi

for file in "${files[@]}"
do
    touch ${file}
    if ! grep -qc '/jabba.sh' "${file}"; then
        echo "Adding source string to ${file}"
        printf "$SOURCE_JABBA\n" >> "${file}"
    else
        echo "Skipped update of ${file} (source string already present)"
    fi
done

if [ -f "$(which zsh 2>/dev/null)" ]; then
    file="$HOME/.zshrc"
    touch ${file}
    if ! grep -qc '/jabba.sh' "${file}"; then
        echo "Adding source string to ${file}"
        printf "$SOURCE_JABBA\n" >> "${file}"
    else
        echo "Skipped update of ${file} (source string already present)"
    fi
fi

{
echo "# https://github.com/shyiko/jabba"
echo "# This file is indented to be \"sourced\" (i.e. \". ~/.jabba/jabba.fish\")"
echo ""
echo "set -xg JABBA_HOME \"$JABBA_HOME_TO_EXPORT\""
echo ""
echo "function jabba"
echo "    set fd3 (mktemp /tmp/jabba-fd3.XXXXXX)"
echo "    env JABBA_SHELL_INTEGRATION=ON $JABBA_HOME_TO_EXPORT/bin/jabba \$argv 3> \$fd3"
echo "    set exit_code \$status"
echo "    eval (cat \$fd3 | sed \"s/^export/set -xg/g\" | sed \"s/^unset/set -e/g\" | tr '=' ' ' | sed \"s/:/\\\" \\\"/g\" | tr '\\\\n' ';')"
echo "    rm -f \$fd3"
echo "    return \$exit_code"
echo "end"
echo ""
echo "[ ! -z (echo (jabba alias default)) ]; and jabba use default"
} > ${JABBA_HOME}/jabba.fish

FISH_SOURCE_JABBA="\n[ -s \"$JABBA_HOME/jabba.fish\" ]; and source \"$JABBA_HOME/jabba.fish\""

if [ -f "$(which fish 2>/dev/null)" ]; then
    file="$HOME/.config/fish/config.fish"
    mkdir -p $(dirname ${file})
    touch ${file}
    if ! grep -qc '/jabba.fish' "${file}"; then
        echo "Adding source string to ${file}"
        printf "$FISH_SOURCE_JABBA\n" >> "${file}"
    else
        echo "Skipped update of ${file} (source string already present)"
    fi
fi

echo ""
echo "Installation completed
(if you have any problems please report them at https://github.com/shyiko/jabba/issues)"

} # this ensures the entire script is downloaded
