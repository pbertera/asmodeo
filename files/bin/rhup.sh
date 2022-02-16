#!/bin/bash
# This script starts the VPN with NetworkManager using the 2FA
# All the required secrets (Tocken PIN and secret, Kerberos password)
# are stored into a pass (https://www.passwordstore.org/) database
#
# TODO:
#
# * use keepassxc-cli for secrets and geting the OTP
# * use an USB drive with the secrets
# * temporary nicknames, use zenity to ask the user if we should revert to the default nick
# * use notify-send to send desktop notification
# * login on the rhportal
#
# Name of the VPN connection
#VPN_CONNECTION="1 - Red Hat Global VPN"
#VPN_CONNECTION="Amsterdam (AMS2)"
VPN_CONNECTION="Brno (BRQ)"
# Your Kerberos ID
KRB_ID="pbertera@IPA.REDHAT.COM"
# The token PIN
PASS_TOKEN_PIN_PATH="RH/token/pin"
# The token secret
PASS_TOKEN_SECRET_PATH="RH/token/secret"
OATHTOOL_OPTS="-b --totp"
# The Kerberos password
PASS_KRB_PATH="RH/krb"
# The SSO password
PASS_SSO_PATH="RH/sso"
# Hexchat network name
# TODO: in case of multiple servers configured we should find a whay to detect the server in use
IRC_NETWORK="irc.devel.redhat.com"
#IRC_NETWORK="irc.eng.brq.redhat.com"
#IRC_NETWORK="chat.freenode.net" # test
# Default nickname on $IRC_NETWORK
IRC_NICK="pbertera"
# where to save the last IRC nickname
NICKFILE=~/.lastnick
# when these programs are running I'm in a meeting
MEETING_PROGRAMS="bluejeans-v2"
# when on of these devices are in use I'm in a meeting
MEETING_DEVICES="/dev/video*"
# meeting IRC nick suffix
MEETING_SUFFIX=mtg
# name of the systemd timer to monitor the nick
SYSTEMD_MONITOR=autoIRCnickMonitor
# value of --on-calendar option of systemd-run used to register the timer to check if I'm in a meeting
SYSTEMD_MONITOR_FREQ='*-*-* *:*:00'
# SSH command to login on supportshell
SUPPORTSHELL="ssh -t -S ~/.ssh/supportshell supportshell"

# define colors in an array
if [[ $BASH_VERSINFO -ge 4 ]]; then
    declare -A c
    c[reset]='\033[0;0m'
    c[grey]='\033[00;30m';  c[GREY]='\033[01;30m';  c[bg_GREY]='\033[40m'
    c[red]='\033[0;31m';    c[RED]='\033[1;31m';    c[bg_RED]='\033[41m'
    c[green]='\E[0;32m';  c[GREEN]='\033[1;32m';  c[bg_GREEN]='\033[42m'
    c[orange]='\033[0;33m'; c[ORANGE]='\033[1;33m'; c[bg_ORANGE]='\033[43m'
    c[blue]='\033[0;34m';   c[BLUE]='\033[1;34m';   c[bg_BLUE]='\033[44m'
    c[purple]='\033[0;35m'; c[PURPLE]='\033[1;35m'; c[bg_PURPLE]='\033[45m'
    c[cyan]='\033[0;36m';   c[CYAN]='\033[1;36m';   c[bg_CYAN]='\033[46m'
fi

# print text to screen
function print {
    # usage:
    # print red WARNING You have encounted an error!
    #
    # returns:
    # [ WARNING ] You have encounted an error!
    #
    # use colors in the array above this function
    local COLOR=$1
    local VERB=$2
    local MSG=$(echo $@ | cut -d' ' -f3-)
    [[ "${MSG: -1}" == "?"  ]] && {
        echo -ne " [${c[$COLOR]}$VERB${c[reset]}] ${MSG::-1}"
    } || {
        echo -e " [${c[$COLOR]}$VERB${c[reset]}] $MSG"
    }
}

# HINT: hexchat, use d-feet to browse the dbus interface

function IRCSetContext {
    local context=$(dbus-send --dest=org.hexchat.service --print-reply --type=method_call /org/hexchat/Remote org.hexchat.plugin.FindContext string:"$IRC_NETWORK" string:"" | tail -n1 | awk '{print $2}')
    dbus-send --dest=org.hexchat.service --type=method_call /org/hexchat/Remote org.hexchat.plugin.SetContext uint32:$context
}

function IRCCommand {
    if [ $# -eq 0 ]; then
        print red ERROR $0 requires a command
        exit 1
    fi
    dbus-send --dest=org.hexchat.service --type=method_call /org/hexchat/Remote org.hexchat.plugin.Command string:"$@"
}

# check if one of the programs defined by MTG_PROGRAMS is running
# if yes, return the nick suffix to use when in a meeting
function isMeetingActive {
    pidof $MEETING_PROGRAMS &> /dev/null && return 0
    fuser $MEETING_DEVICES &> /dev/null && return 0
    #grep owner_pid /proc/asound/card*/pcm*/sub*/status &> /dev/null && return 0
    return 1
}

# check the status of the systemd timer monitoring the nick
# if not running will be started
function startSystemdMonitor {
    systemctl --user status "${SYSTEMD_MONITOR}.timer" &> /dev/null
    if [ $? -ne 0 ]; then
        systemd-run --user --on-calendar="$SYSTEMD_MONITOR_FREQ" --unit="$SYSTEMD_MONITOR" ${BASH_SOURCE[1]} ircNickAuto
        print orange INFO systemd timer ${SYSTEMD_MONITOR} started
    else
        print orange INFO systemd timer ${SYSTEMD_MONITOR} running
    fi
}

function stopSystemdMonitor {
    systemctl --user status "${SYSTEMD_MONITOR}.timer" &> /dev/null
    if [ $? -eq 0 ]; then
        systemctl --user stop ${SYSTEMD_MONITOR}.timer
        print orange INFO systemd timer ${SYSTEMD_MONITOR} stopped
    else
        print orange INFO systemd timer ${SYSTEMD_MONITOR} not running
    fi
}

# if the secret isn't found into the defined path will be added
function getPass {
    local passPath="$1"
    pass ls "$passPath" >/dev/null 2>&1 || pass insert "$passPath"
    pass "$passPath"
}

# generate the token TODO: token type should be configurable
function genToken {
    oathtool $OATHTOOL_OPTS "$TOKEN_SECRET"
}

# set up the VPN
function vpnUp {
    echo "${TOKEN_PIN}$(genToken)" | nmcli --ask connection up "$VPN_CONNECTION"
}

# tear down the VPN
function vpnDown {
    nmcli connection down "$VPN_CONNECTION"
}

# check if the VPN is active
function isVpnUp {
    ping -q -c1 ldap.corp.redhat.com >/dev/null 2>&1
}

# get all the needed secrets
function setup {
    TOKEN_PIN=$(getPass "$PASS_TOKEN_PIN_PATH")
    TOKEN_SECRET=$(getPass "$PASS_TOKEN_SECRET_PATH")
    KRB_PASS=$(getPass "$PASS_KRB_PATH")
    SSO_USER=$(getPass "$PASS_SSO_PATH" | tail -n1)
    SSO_PASS=$(getPass "$PASS_SSO_PATH" | head -n1)
}

function status {
    fatalColor=$1
    fatalColor=${fatalColor:-orange}
    isVpnUp
    if [ $? == 0 ]; then
        print green INFO VPN is UP
    else
        print $fatalColor INFO VPN is DOWN
    fi
    shopt -s lastpipe
    klist 2>/dev/null | grep krbtgt | awk '{print $3, $4}'| read krb_token
    if [ ${PIPESTATUS[0]} == 0 ]; then
        print green INFO Kerberos token is valid till $krb_token
    else
        print $fatalColor INFO Kerberos token not present
    fi
    systemctl --user status "${SYSTEMD_MONITOR}.timer" --no-pager
    if [ $? -ne 0 ]; then
        print orange WARNING systemd timer ${SYSTEMD_MONITOR} not running
    fi
}

function usage {
    cat << EOF

Usage: $0 <action>

Actions:

- up:   * activate the VPN using Network Manager, the VPN name is defined by the VPN_CONNECTION variable
        * initializes the Kerberos token, the token id is defined via the KRB_ID variable
        * connects HexChat to the IRC network (HexChat must be already configured), the network is selected by the IRC server defined with IRC_NETWORK
        * the IRC nick is defined to via the variable IRC_NICK, if a nick was saved into the file NICKFILE the old nick is preserved
        * starts the systemd timer defined by SYSTEMD_MONITOR. You can see it via the 'systemctl --user list-timers' command
        * see the action 'startSystemdMonitor' for more info about the timer

- down: * deactivate the VPN
        * the kerberos ticket is destroyed
        * the systemd timer is stopped

- status:   * print the current status

- getToken: * the OTP token is copied into the clipboard for 20 seconds

- ircNick:  * adds a suffix to the nick defined by IRC_NICK, if the suffix contains 'away', 'gone', 'PTO' or 'brb' sets you away on IRC.
            * if you are set away the systemd timer is deactivated

- ircAway:  * sets you away on IRC

- ircBack:  * sets you back on IRC

- ircNickAuto:  * checks if one the programs defined by MEETING_PROGRAMS is running  and in case adds the IRC nick suffix defined by MEETING_SUFFIX

- startSystemdMonitor:   * activate a systemd timer triggering the command '$0 ircNickAuto'.
                            * the frequency of the timer is defined by SYSTEMD_MONITOR_FREQ
                            * the unit name is defined by SYSTEMD_MONITOR_FREQ

- stopSystemdMonitor:    * removes the systemd timer activated by 'startSystemdMonitor'
EOF
    exit 1

}

action="$1"

case "$action" in
    vpnUp)
        setup
        vpnUp
        ;;
    vpnDown)
        setup
        vpnDown
        ;;
    up)
        setup
        isVpnUp || vpnUp
        echo "$KRB_PASS" | kinit "$KRB_ID">/dev/null
        status red
        IRCSetContext
        sleep 5
        if [ -e $NICKFILE ]; then
            IRC_NICK=$(cat $NICKFILE)
        fi
        IRCCommand "nick $IRC_NICK"
        IRCCommand back
        startSystemdMonitor
        ;;
    down)
        isVpnUp && vpnDown
        kdestroy
        stopSystemdMonitor
        status
        ;;
    status)
        status
        ;;
    genToken)
		setup
		genToken
		;;
    getToken)
        setup
        echo "${TOKEN_PIN}$(genToken)" | xclip
        print orange INFO PIN+Token has been copied into the clipboard for 20 seconds
        sleep 20 && echo -n | xclip & 
        ;;
    yank)
        shift
        if [ "$1" == "" ]; then
            print red ERROR: yank command requires a case number
        fi
        setup
        set -x
        $SUPPORTSHELL /bin/bash -c "echo -ne '${SSO_USER}\n${SSO_PASS}' | yank -t -y -a $1 && cd $1 && /bin/bash"
        #$SUPPORTSHELL 
        ;;
    ircNick)
        shift
        IRCSetContext
        if [ $# -ne 0 ]; then
            IRC_NICK="$IRC_NICK $@"
        fi
        print orange INFO Changing nick to ${IRC_NICK// /|}
        IRCCommand "nick ${IRC_NICK// /|}"

        if [ "$1" == "gone" ] || [ "$1" == "away" ] || [ "$1" == "PTO" ] || [ "$1" == "brb" ]; then
            # mark me as away
            IRCCommand away
            # stop the nick monitor
            stopSystemdMonitor
        else
            if [ -e $NICKFILE ]; then
                # set back on IRC if the previous nick was with away/gone/brb
                grep -e away -e gone -e PTO -e brb $NICKFILE &>/dev/null
                if [ $? -eq 0 ]; then
                    # start the nick monitor
                    startSystemdMonitor
                    IRCCommand back
                fi
            fi
        fi
        # save the last nick
        echo ${IRC_NICK// /|} > $NICKFILE

        ;;
    ircNickAuto)
        shift
        isVpnUp || blink1-tool --magenta --blink 3
        isMeetingActive
        if [ $? -eq 0 ]; then # I'm in a meeting set the meeting suffix
            $0 ircNick $MEETING_SUFFIX
            blink1-tool --red
        else # meeting programs are not running
            # if the old nick was with the meeting suffix reset the nick
            grep $MEETING_SUFFIX $NICKFILE &>/dev/null && $0 ircNick
            blink1-tool --off
        fi
        exit 0
        ;;
    startSystemdMonitor)
        shift
        startSystemdMonitor
        ;;
    stopSystemdMonitor)
        shift
        stopSystemdMonitor
        ;;
    ircAway)
        print orange INFO Setting IRC status away
        IRCCommand away
        ;;
    ircBack)
        print orange INFO Setting IRC status back
        IRCCommand back
        ;;
    *)
        usage
        ;;
esac
