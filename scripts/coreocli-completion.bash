# bash completion for coreo                                -*- shell-script -*-

__debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__my_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__handle_reply()
{
    __debug "${FUNCNAME[0]}"
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            COMPREPLY=( $(compgen -W "${allflags[*]}" -- "$cur") )
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%%=*}"
                __index_of_word "${flag}" "${flags_with_completion[@]}"
                if [[ ${index} -ge 0 ]]; then
                    COMPREPLY=()
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zfs completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    COMPREPLY=( $(compgen -W "${completions[*]}" -- "$cur") )

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        COMPREPLY=( $(compgen -W "${noun_aliases[*]}" -- "$cur") )
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        declare -F __custom_func >/dev/null && __custom_func
    fi

    __ltrim_colon_completions "$cur"
}

# The arguments should be in the form "ext1|ext2|extn"
__handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__handle_flag()
{
    __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    if [ -n "${flagvalue}" ] ; then
        flaghash[${flagname}]=${flagvalue}
    elif [ -n "${words[ $((c+1)) ]}" ] ; then
        flaghash[${flagname}]=${words[ $((c+1)) ]}
    else
        flaghash[${flagname}]="true" # pad "true" for bool flag
    fi

    # skip the argument to a two word flag
    if __contains_word "${words[c]}" "${two_word_flags[@]}"; then
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__handle_noun()
{
    __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__handle_command()
{
    __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_$(basename "${words[c]//:/__}")"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F $next_command >/dev/null && $next_command
}

__handle_word()
{
    if [[ $c -ge $cword ]]; then
        __handle_reply
        return
    fi
    __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __handle_flag
    elif __contains_word "${words[c]}" "${commands[@]}"; then
        __handle_command
    elif [[ $c -eq 0 ]] && __contains_word "$(basename "${words[c]}")" "${commands[@]}"; then
        __handle_command
    else
        __handle_noun
    fi
    __handle_word
}

_coreo_cloud_add()
{
    last_command="coreo_cloud_add"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloud-id=")
    local_nonpersistent_flags+=("--cloud-id=")
    flags+=("--key=")
    two_word_flags+=("-K")
    local_nonpersistent_flags+=("--key=")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--secret=")
    two_word_flags+=("-S")
    local_nonpersistent_flags+=("--secret=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_cloud_delete()
{
    last_command="coreo_cloud_delete"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloud-id=")
    local_nonpersistent_flags+=("--cloud-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_cloud_list()
{
    last_command="coreo_cloud_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_cloud_show()
{
    last_command="coreo_cloud_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--cloud-id=")
    local_nonpersistent_flags+=("--cloud-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_cloud()
{
    last_command="coreo_cloud"
    commands=()
    commands+=("add")
    commands+=("delete")
    commands+=("list")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_add()
{
    last_command="coreo_composite_add"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--git-repo=")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--git-repo=")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_extends()
{
    last_command="coreo_composite_extends"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--add-server-directories")
    flags+=("-s")
    local_nonpersistent_flags+=("--add-server-directories")
    flags+=("--directory=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--directory=")
    flags+=("--git-repo=")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--git-repo=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_gendoc()
{
    last_command="coreo_composite_gendoc"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--add-server-directories")
    flags+=("-s")
    local_nonpersistent_flags+=("--add-server-directories")
    flags+=("--directory=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--directory=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_init()
{
    last_command="coreo_composite_init"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--add-server-directories")
    flags+=("-s")
    local_nonpersistent_flags+=("--add-server-directories")
    flags+=("--directory=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--directory=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_layer()
{
    last_command="coreo_composite_layer"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--add-server-directories")
    flags+=("-s")
    local_nonpersistent_flags+=("--add-server-directories")
    flags+=("--directory=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--directory=")
    flags+=("--git-repo=")
    two_word_flags+=("-g")
    local_nonpersistent_flags+=("--git-repo=")
    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_list()
{
    last_command="coreo_composite_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite_show()
{
    last_command="coreo_composite_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_composite()
{
    last_command="coreo_composite"
    commands=()
    commands+=("add")
    commands+=("extends")
    commands+=("gendoc")
    commands+=("init")
    commands+=("layer")
    commands+=("list")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_configure_list()
{
    last_command="coreo_configure_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_configure()
{
    last_command="coreo_configure"
    commands=()
    commands+=("list")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_git-key_add()
{
    last_command="coreo_git-key_add"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name=")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name=")
    flags+=("--secret=")
    two_word_flags+=("-S")
    local_nonpersistent_flags+=("--secret=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_git-key_delete()
{
    last_command="coreo_git-key_delete"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--gitKey-id=")
    local_nonpersistent_flags+=("--gitKey-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_git-key_list()
{
    last_command="coreo_git-key_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_git-key_show()
{
    last_command="coreo_git-key_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--gitKey-id=")
    local_nonpersistent_flags+=("--gitKey-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_git-key()
{
    last_command="coreo_git-key"
    commands=()
    commands+=("add")
    commands+=("delete")
    commands+=("list")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_add()
{
    last_command="coreo_plan_add"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--branch=")
    local_nonpersistent_flags+=("--branch=")
    flags+=("--cloud-id=")
    local_nonpersistent_flags+=("--cloud-id=")
    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--directory=")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--directory=")
    flags+=("--interval=")
    local_nonpersistent_flags+=("--interval=")
    flags+=("--name=")
    local_nonpersistent_flags+=("--name=")
    flags+=("--region=")
    local_nonpersistent_flags+=("--region=")
    flags+=("--revision=")
    local_nonpersistent_flags+=("--revision=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_delete()
{
    last_command="coreo_plan_delete"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--plan-id=")
    local_nonpersistent_flags+=("--plan-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_disable()
{
    last_command="coreo_plan_disable"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--plan-id=")
    local_nonpersistent_flags+=("--plan-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_enable()
{
    last_command="coreo_plan_enable"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--plan-id=")
    local_nonpersistent_flags+=("--plan-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_finalize()
{
    last_command="coreo_plan_finalize"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--file=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_list()
{
    last_command="coreo_plan_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_panel()
{
    last_command="coreo_plan_panel"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--plan-id=")
    local_nonpersistent_flags+=("--plan-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan_show()
{
    last_command="coreo_plan_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--composite-id=")
    local_nonpersistent_flags+=("--composite-id=")
    flags+=("--plan-id=")
    local_nonpersistent_flags+=("--plan-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_plan()
{
    last_command="coreo_plan"
    commands=()
    commands+=("add")
    commands+=("delete")
    commands+=("disable")
    commands+=("enable")
    commands+=("finalize")
    commands+=("list")
    commands+=("panel")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_team_list()
{
    last_command="coreo_team_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_team_show()
{
    last_command="coreo_team_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_team()
{
    last_command="coreo_team"
    commands=()
    commands+=("list")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_token_delete()
{
    last_command="coreo_token_delete"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--token-id=")
    local_nonpersistent_flags+=("--token-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_token_list()
{
    last_command="coreo_token_list"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_token_show()
{
    last_command="coreo_token_show"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--token-id=")
    local_nonpersistent_flags+=("--token-id=")
    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_token()
{
    last_command="coreo_token"
    commands=()
    commands+=("delete")
    commands+=("list")
    commands+=("show")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo_version()
{
    last_command="coreo_version"
    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_coreo()
{
    last_command="coreo"
    commands=()
    commands+=("cloud")
    commands+=("composite")
    commands+=("configure")
    commands+=("git-key")
    commands+=("plan")
    commands+=("team")
    commands+=("token")
    commands+=("version")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api-key=")
    flags+=("--api-secret=")
    flags+=("--endpoint=")
    flags+=("--home=")
    flags+=("--json")
    flags+=("--profile=")
    flags+=("--team-id=")
    flags+=("--verbose")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_coreo()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __my_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("coreo")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_coreo coreo
else
    complete -o default -o nospace -F __start_coreo coreo
fi

# ex: ts=4 sw=4 et filetype=sh
