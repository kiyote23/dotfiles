; $Id: mcp.tf,v 1.4 1998/06/05 07:14:11 bj Exp $
;
; MCP 1.0 support for TinyFugue.  You'll need to enable local editing and
; mcp editing on your MOO to take advantage of this.  You'll need a pretty
; recent version of TF (available from ftp://tf.tcp.com/pub/tinyfugue/)
; and you'll need to make sure you use a world type of tiny.moo for all
; your moo worlds (ie /addworld -Ttiny.moo ...).
;
; The only builtin support is for the `edit' request.  Supporting other
; requests is easy.  If you wanted to handle #$#gopher, you'd just define
; a mcp_gopher macro.  This macro should use the variables mcp_tag_host,
; mcp_tag_port, mcp_tag_path and mcp_tag_description which will have been
; parsed out of the request.  For example, a simple implementation using
; lynx:
;
;	/def mcp_gopher = /sh lynx gopher:///%{mcp_tag_host}:%{mcp_tag_port-70}/%{mcp_tag_path}
;	/mcp_add_client_option gopher
;
; Note that we provide a default for the optional `port' tag and catered
; to TF's desire to eat one of the slashes in gopher://.  If you do this
; interactively, try /mcp_login to send the new client option string.
;
; Or how about using netscape to view URLs?
;
;	/def mcp_display-url = /sys netscape -remote "openURL(%{mcp_tag_url})"
;	/mcp_add_client_option url
;
; The existing edit support will do background editing (TF continues to
; run while your editor runs under X or in another screen window) and
; foreground editing, where the editor runs on the same TTY as TF and TF
; is suspended while the editor runs.  Most of this is completely automatic,
; but you can play with the configuration below.  Stuff is uploaded after
; you save and quit your editor.  You can re-edit the last thing that
; was sent to a given world with /reedit.
;
; For more info on MCP, see http://jhm.ccs.neu.edu:7043/help/subject!mcp
; For more info on TinyFugue, see http://tf.tcp.com/~hawkeye/tf/
; For more info on me, see http://www.ben.com/~ben/
;
; Thanks to Hawkeye (Ken Keys) for his help and suggestions.  Thanks to
; Crag (Robert de Forest) for alpha testing and giving me the opportunity
; to fix all the quirks once instead of being flooded by email.
;

/require lisp.tf
/~loaded mcp.tf

; this is where unprefix.ed resides.  we need this file to strip @@@ prefixes
;
/set mcp_lib=.

; if theres no unprefix.ed, create the minimal one.  watch out for those
; slashes getting compacted.
;
/eval /sys test -f %{mcp_lib}/unprefix.ed || (echo ',s/^@@@///'; echo w) > %{mcp_lib}/unprefix.ed

; if you're editing in the foreground, we'll call this with /sh, which
; suspends TF and runs this command on TF's tty.
;
/eval /set mcp_editor=%{EDITOR-%{VISUAL-vi}}

; if you want to continue running TF while you edit things, turn on
; mcp_bg_edit, and set mcp_bg_editor to something which doesn't require
; your TF tty to edit (eg emacs with DISPLAY set, xterm -e pico).  This
; command needs to run for the duration of the editing session and exit
; when the text should be sent back to the server.  for commands that exit
; immediately, see the async hack below.
;
/if (DISPLAY !~ "") /set mcp_bg_edit=sync %;/endif
/eval /set mcp_bg_sync_editor=xterm -e %{mcp_editor}

; if you run TF under screen, you can use this grody hack to bring the
; editor up in another screen window.  the problem with screen is that it
; returns control immediately after starting the vi session, so we send tf
; a SIGUSR1 to indicate that the editor has exited.  default screen
; background editing runs mcp_editor (above) in another screen window.
; I'm sure you could write some elisp that would work in concert
; with emacslient to make emacs touch the name.done file after saving.
; We try to grab TTY here if we have async editing, since screen needs to
; know our tty, and /sh is ugly.  If this doesn't work for you, try using
; /sh in the async case of /mcp_edit_invoke.
;
/if (STY !~ "" & mcp_bg_edit =~ "") /set mcp_bg_edit=async %;/endif
/if (mcp_bg_edit =~ "async" & TTY =~ "") \
	/echo % Using async background MCP editing with no TTY set.%;\
	/echo % Try adding "setenv TTY `tty`" to your .login or "TTY=`tty`; export TTY" to your .profile.%;\
	/echo % Trying to determine tty...%;\
	/eval /sh tty > /tmp/kludge.$[getpid()]%;\
	/eval /quote -dexec -S /setenv TTY '/tmp/kludge.$[getpid()]%;\
	/if (TTY =~ "") \
		/echo % Unable to determine tty.  Using /dev/tty -- screen won't switch automatically when you invoke the editor.%;\
		/setenv TTY /dev/tty%;\
	/endif%;\
/endif
; bash is broken and Linux uses it for /bin/sh, so use csh hand hope it's
; more standard and here's a perl version, too
;/eval /set mcp_bg_async_editor=\
;	screen < %{TTY} -t 'mcp edit' perl -e 'system("%{mcp_editor} $$ARGV[0]; touch $$ARGV[0].done");' 
/eval /set mcp_bg_async_editor=\
	screen < %{TTY} -t 'mcp edit' zsh -c '%{mcp_editor} $$1 ;  kill -USR1 $[getpid()]'

;
; check every this many seconds for new .done file
;
/set mcp_bg_async_poll_interval=5

; delete edit files 5 minutes after we upload them.  nothing gets deleted
; if it's the last thing to be uploaded (for /reedit)
;
/set mcp_edit_rm_delay=300

;;
;; END OF USER CONFIGURATION
;;

; generate an auth key named mcp_${world_name}_auth_key
;
/def mcp_gen_auth_key =\
	/eval /set mcp_${world_name}_auth_key=<$[rand()]>
/def mcp_show_auth_key =\
	/eval /eval /echo \%{mcp_${world_name}_auth_key}
/def mcp_check_auth_key =\
	/eval /test {mcp_${world_name}_auth_key} =~ {1}

; keep a unique list of client options we support.  we don't reset the
; list here, because some other .tf may have provided mcp methods already
; and we're just reloading mcp.tf.
;
/def mcp_add_client_option = \
	/set mcp_client_options=$(/unique %{mcp_client_options} %1)

; handle the login negotiation.  note that you can do this by hand if
; you didn't have mcp.tf loaded when you connected to the MOO.
;
/def -Ttiny.moo -t'#\$#mcp version: 1.0' -p10001 -agG mcp_login =\
	/mcp_gen_auth_key %;\
	#\$#authentication-key $(/mcp_show_auth_key)%;\
	#\$#client-options %{mcp_client_options}

; take the end of a server request and parse the tag/value pairs per the
; spec.  note that you can't use `\' to escape arbitrary characters in the
; values, only `"'.  The spec is ambiguous on this point.
;
/def mcp_extract_tags =\
	/while (mcp_tags !~ "") \
		/eval /unset $(/car %{mcp_tags})%;\
		/set mcp_tags=$(/cdr %{mcp_tags})%;\
	/done%;\
	/mcp_extract_tags_internal %{*}

; watch out!  I'm recursive.  also be careful about eval'ing tag values,
; since URLs (in particular) include %'s...
;
/def mcp_extract_tags_internal = \
	/while ({#}) \
		/test regmatch('(.*):', {1})%;\
		/let name=mcp_tag_%{P1}%;\
		/if (0 == strchr({2}, '"')) \
			/test regmatch('"(([\\]"|[^"])*)"(.*)', {-1})%;\
			/let val=%{P1}%;\
			/let rest=%{P3}%;\
			/while (regmatch('(.*)\\\\"(.*)', val)) \
				/let val=%P1"%P2%;\
			/done%;\
			/eval /set %{name}=\%{val}%;\
			/eval /set mcp_tags=%{mcp_tags} %{name}%;\
			/mcp_extract_tags_internal %{rest}%;\
			/break%;\
		/else \
			/eval /set %{name}=\%2%;\
			/eval /set mcp_tags=%{mcp_tags} %{name}%;\
			/shift 2%;\
		/endif %;\
	/done

; receive a line of oob data from the MOO.  check the authentication string,
; parse the tag/value pairs into mcp_tag_*, then call a handler based on
; the message request, eg #$#edit calls /mcp_edit.  At the moment we ignore
; the server-supplied `*' to indicate additional lines of data.
; 
/def -Ttiny.moo -mregexp -t'^#\$#([^* ]*)\*? [^ ]* ' -agG -p10000 mcp_rec_oob =\
	/let request=%{P1}%;\
	/if /mcp_check_auth_key %2%;\
	/then \
		/mcp_extract_tags %-2%;\
		/eval /mcp_%{request}%;\
	/endif

; make up a temporary file name.
;
/def mcp_gen_tempfile =\
	/set mcp_tempfile_seq=$[mcp_tempfile_seq + 1]%;\
	/eval /set mcp_tempfile=.tfmcp$[getpid()].%{mcp_tempfile_seq}

; probably a Bad Idea to use this on non-empty files.
;
/def mcp_edit_done_exists = /test '$(/load %1.done)' =/ '*Loading*'

; wait for an async edit to complete (signaled by touching filename.done)
;
/def mcp_edit_wait_async = \
	/eval /repeat -w${world_name} -%{mcp_bg_async_poll_interval} 1 \
		/if /mcp_edit_done_exists %%{1}%%%;\
		/then \
			/mcp_edit_done %%{*}%%%;\
		/else \
			/mcp_edit_wait_async %%{*}%%%;\
		/endif

; Handle the generic #$#edit request.  All edit requests (regardless of
; type) seem to work alike hence a single macro to handle them all.
;
; some rationale:
;	must turn logging on on the first @@@ and not immediately because
;	otherwise the #$#edit line gets logged.
;	lots of use of eval to use macro names that include the world name
;	use /quote to invoke the editor so tf doesn't block but we still
;	notice when it exits. (for sync bg)
;	use /sh to invoke async bg so screen will have a tty (boo, hiss)
;	trigger of #$$$# because it gets expanded a few times, eww
;
/mcp_add_client_option mcp-edit
/def mcp_edit =\
	/mcp_gen_tempfile%;\
	/eval /def -p10000 -F -n1 -t'@@@*' mcp_${world_name}_save_body_logstart = /log -w${world_name} %{mcp_tempfile}%;\
	/eval /def -mregexp -p9999 -t'^@@@(.*)' -agG -w${world_name} mcp_${world_name}_save_body_trig = %;\
	/eval /def -t'#$$$#END' -p10000 -w${world_name} -agG -n1 mcp_${world_name}_save_body_end =\
		/eval /log -w${world_name} off%%%;\
		/eval /purge mcp_${world_name}_save_body_*%%%;\
		/sys ed -s %{mcp_tempfile} < %{mcp_lib}/unprefix.ed %%%;\
		/mcp_edit_invoke %{mcp_tempfile} %{mcp_tag_upload}

; eval overdose here because this used to be entirely within an /eval
;
/def mcp_edit_invoke = \
	/if (mcp_bg_edit =~ "sync") \
		/eval /quote -dexec -w${world_name} -0 !sh -c "%{mcp_bg_sync_editor} %1; echo '/mcp_edit_done %*'"%;\
	/elseif (mcp_bg_edit =~ "async") \
		/def -1 -hSIGUSR1 = /mcp_edit_done %*%;\
		/sys %{mcp_bg_async_editor} %1%;\
	/else \
		/sh %{mcp_editor} %{mcp_tempfile}%;\
		/mcp_edit_done %*%;\
	/endif

; upload the body, delete the tempfile in about 5 minutes unless it's
; still the last re-edit
;
/def mcp_edit_done =\
	/send %-1%;\
	/eval /quote -0 -w${world_name} !sed -e 's/^[.]/../' %1; echo .                                                                                                                                                                                                    %;\
	/set mcp_edit_reedit_${world_name}=%*%;\
	/sys rm -f %{1}.done %;\
	/if (mcp_edit_rm_delay) \
		/eval /repeat -%{mcp_edit_rm_delay} 1 \
			/if (mcp_edit_reedit_${world_name} !/ "%1 *") \
				/sys rm -f %1%%%;\
			/endif%;\
	/endif

; re-edit the last thing we uploaded
;
/def mcp_reedit = \
	/if /eval /test "\%{mcp_edit_reedit_${world_name}}" !~ "" %;\
	/then \
		/eval /mcp_edit_invoke \%{mcp_edit_reedit_${world_name}}%;\
	/else \
		/echo %% Nothing to re-edit in world ${world_name}.%;\
	/endif
; an alias
/def reedit = /mcp_reedit
