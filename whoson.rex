/* REXX */
  /* --------------------  rexx procedure  -------------------- *
  | Name:      WHOSON                                          |
  |                                                            |
  | Function:  Using SDSF REXX query for all TSO users and     |
  |            all SSH users on all systems in the SYSPLEX.    |
  |                                                            |
  |            Also report on any other address spaces         |
  |            - find *custom* and follow instructions         |
  |                                                            |
  | Syntax:    %whoson option \ prefix-or-filter               |
  |                                                            |
  |            option: B - ISPF Browse results                 |
  |                    V - ISPF View results                   |
  |                    null - REXX say                         |
  |                    ? - display help info                   |
  |                                                            |
  |            prefix - any char string prefixing userid       |
  |                     e.g. SPL                               |
  |            filter - any chars within a userid              |
  |                     e.g. *L or L*                          |
  |                                                            |
  | Dependencies:  SDSF REXX                                   |
  |                STEMEDIT for Browse/View                    |
  |                RACF LU                                     |
  |                                                            |
  | Customizations:  1. Change RACFLU variable from 1 to 0     |
  |                     - if you don't have RACF               |
  |                     - if made available to those who can't |
  |                       do an LU for other userids.          |
  |                  2. Other define other started tasks to    |
  |                     check by reading the JESMSGLG and      |
  |                     extracting the ICH... userid           |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            2024/06/24 LBD - Allow multiple others          |
  |            2024/06/21 LBD - Add date/time for users        |
  |            2024/06/19 LBD - Clean up                       |
  |                           - can't use dates                |
  |            2024/06/05 LBD - Fix one more bug with other    |
  |            2024/06/04 LBD - Clean up SDSF for Other        |
  |            2024/06/03 LBD - Add Other users                |
  |                             implemented for Gateway z/OS   |
  |                             web TSO address spaces         |
  |            2024/01/31 LBD - Enable to run under OMVS shell |
  |                           - correct for names with ,'s     |
  |                             with text before , going last  |
  |            2023/11/06 LBD - Sort lpar names                |
  |            2023/11/05 PJF - Clean up filters for PS        |
  |            2023/10/31 LBD - Fix for filtering              |
  |            2023/10/28 LBD - Fix if racflu is 1 but s/b 0   |
  |            2023/10/26 LBD - Split Total users into TSO/SSH |
  |            2023/10/23 LBD - Add ssh users                  |
  |            2022/03/31 LBD - Add option to bypass RACF LU   |
  |            2022/03/14 LBD - Use SDSF DA instead of RO cmd  |
  |                           - add filter option              |
  |                           - Fix case of user name          |
  |            2022/03/11 LBD - Cleanup/improve report         |
  |            2022/03/04 LBD - Creation                       |
  |                                                            |
  * ---------------------------------------------------------- */

  arg option '\' prefix .

  /* -------------- *
  | Check for Help |
  * -------------- */
  if strip(option) = '?' then call do_help

  /* -------------------- *
  | Define key variables |
  * -------------------- */
  parse value '' with null lpars users. tpref

  /* ------------------------------------------------------------ *
  | Site Customizations   *custom*                               |
  |                                                              |
  |    RACFLU - allow or disallow doing an LU to get the name of |
  |             the TSO users.                                   |
  |                                                              |
  |             0 = Do not allow                                 |
  |             1 = Allow                                        |
  |                                                              |
  |    OTHER  - other address space names, or prefixes, to       |
  |             report on                                        |
  |                                                              |
  |             null = ignore                                    |
  |             ABC = look just for ABC                          |
  |             AB* = look for prefix AB                         |
  |                                                              |
  * ------------------------------------------------------------ */
  RACFLU = 1
  OTHER  = null

  /* -------------------------- *
  | Enable SDSF Rexx Interface |
  * -------------------------- */
  x = isfcalls('on')

  /* --------------------------------- *
  | Check and configure Prefix/Filter |
  * --------------------------------- */
  if length(prefix) > 0 then do
    if pos('*',prefix) > 0
    then tpref = strip(translate(prefix,' ','*'))
    else tpref = strip(translate(prefix))
  end

  parse value '0 0 0' with ssh_users tso_users other_users

  call Do_TSO
  drop stdate. date. datee.
  isfcols = null
  call Do_SSH
  drop stdate. date. datee.
  isfcols = null
  call Do_Other

  /* ----------------------- *
  | Now Generate our Report |
  * ----------------------- */
  c = 2
  r.1 = 'Interactive Users on' words(lpars) 'Systems:',
    'TSO Users:' tso_users 'SSH Users:' ssh_users
  if other_users > 0 then
  r.1 = r.1 'Other Users:' other_users
  r.2 = copies('-',length(r.1))
  lpars = sortstr(lpars)
  do i = 1 to words(lpars)
    lpar = word(lpars,i)
    users = sortstr(users.lpar)
    c = c + 1
    r.c = 'System:  ' left(lpar,8) 'Users:' words(users)
    do iu = 1 to words(users)
      c = c + 1
      uid = word(users,iu)
      if right(uid,1) = '>'
      then do
        sshflag = '(ssh)'
        name = subword(users.uid,1)
        tuid = left(uid,length(uid)-1)
      end
      else do
        sshflag = null
        tuid = uid
      end
      if pos('.',tuid) > 0
         then parse value tuid with tuid'.' .
      r.c = left(tuid,9) users.uid  left(users.uid.dt,20) sshflag
    end
    c = c + 1
    r.c = copies('-',length(r.1))
  end
  r.0 = c

  /* -------------------------- *
  | Report out based on option |
  * -------------------------- */
  if strip(option) = null then do
    do i = 1 to r.0
      say r.i
    end
    exit 0
  end
  if option = 'B' then opt = 'Browse'
  if option = 'V' then opt = 'View'

Do_StemEdit:
  call stemedit opt,'r.'
  Exit 0

Do_TSO:
  /* ------------------ *
  | Define our filters |
  * ------------------ */
  isfsysname = '*'
  isfowner = "*"
  isfprefix = tpref'*'
  isffilter = 'jobid t*'
  /* --------------- TSO ---------------- *
  | Extract the system names and userids |
  * ------------------------------------ */
  Address SDSF "ISFEXEC da"
  do i = 1 to jname.0
    lpar = sysname.i
    user = jname.i
    if wordpos(lpar,lpars) = 0
    then lpars = lpars lpar
    tso_users = tso_users + 1
    users.lpar = users.lpar strip(user)
    if racflu = 1
    then users.user = left(get_user_name(user),20)
    else users.user = null
    users.user.dt = stdate.i
  end
  Return

Do_SSH:
  /* --------------- SSH ---------------- *
  | Extract the system names and userids |
  * ------------------------------------ */
  isfprefix = '*'
  isfowner = tpref"*"
  isffilter = 'jname sshd*'
  Address SDSF "ISFEXEC ps"
  do i = 1 to jname.0
    if jobid.i /= null then iterate
    lpar = sysname.i
    user = ownerid.i
    if wordpos(lpar,lpars) = 0
    then lpars = lpars lpar
    user = strip(left(user'>',9))
    if wordpos(user,users.lpar) > 0 then iterate
    ssh_users = ssh_users + 1
    users.lpar = users.lpar user
    if racflu = 1
    then users.user = left(get_user_name(ownerid.i),20)
    else users.user = null
    users.user.dt = datee.i fix_timee(timee.i)
  end
  Return

Fix_Timee: procedure
  arg timee
  parse value timee with hh':'mm':'ss'.'.
  return right(hh+100,2)':'mm':'ss

Do_Other:
  /* ---------------------------------------------------- *
  | Add address space prefixes (e.g. XX* AB*) to process |
  | If blank then no other check will be performed.      |
  * ---------------------------------------------------- */
  if strip(other) = null then return
  do ispec = 1 to words(other)
  /* -------------- *
   | Define filters |
   * -------------- */
    isfsysname = ''
    isfowner = "*"
    isfdest = ' '
    isffilter = null
    isfprefix =  word(other,ispec)
    Address SDSF "ISFEXEC da"
  /* --------------------------------------------------- *
   | Now get the information on the other address spaces |
   * --------------------------------------------------- */
    do i = 1 to jname.0
      lpar = sysname.i
      user = jname.i
      userz = user || '.'i
      if wordpos(lpar,lpars) = 0
      then lpars = lpars lpar
      other_users = other_users + 1
      users.lpar = users.lpar strip(userz)
      users.userz.dt = stdate.i
      ouser = get_other_user_name()
      users.userz = left(get_user_name(ouser),20)
    end
  end
  Return

  /* ------------------------ *
  | Display help information |
  * ------------------------ */
Do_Help:
  r.1 = 'WHOSON Syntax and Information.'
  r.2 = ' '
  r.3 = 'Syntax: %WHOSON option \ prefix-or-filter'
  r.4 = ' '
  r.5 = ' option may be: null    display on terminal'
  r.6 = '                B       use ISPF Browse'
  r.7 = '                V       use ISPF View'
  r.8 = '                ?       display this help information'
  r.9 = ' '
  r.10 = ' \ is a required separator (in case of a null option)'
  r.11 = ' '
  r.12 = ' prefix is a TSO User ID prefix to limit the report.'
  r.13 = '        e.g. SPL'
  r.14 = ' filter is a string to find in the userid.'
  r.15 = '        e.g. *L or L*'
  r.16 = ' '
  r.17 = 'Dependencies:   SDSF REXX'
  r.18 = '                STEMEDIT'
  r.0 = 18

  opt =  'Browse'
  if sysvar('sysispf') = 'ACTIVE'
  then if sysvar('sysenv') = 'FORE'
  then call do_stemedit
  do i = 1 to r.0
    say r.i
  end
  Exit 0

  /* --------------------------------- *
  | Extract the User's Name from RACF |
  * --------------------------------- */
Get_User_Name:
  arg uid .
  if right(uid,1) = '>'
  then  tuid = left(uid,length(uid)-1)
  else tuid = uid
  if pos('.',uid) > 0
     then parse value uid with uid'.' .
  call  outtrap 'uid.'
  Address TSO 'lu' tuid
  lurc = rc
  call outtrap 'off'
  if lurc > 0 then do
    racflu = 0
    name = null
    drop uid.
    return name
  end
  parse value uid.1 with .'NAME='name 'OWNER='.
  drop uid.
  return strip(cap1st(name))
  name = 'None'
  drop uid.
  return name

  /* ------------------------------------------------------ *
   | Get Other User by looking in the JOBs JESMSGLG for the |
   | ICH70001I message for the userid                       |
   * ------------------------------------------------------ */
Get_Other_User_Name:
  x = isfcalls('on')
  isfsysname = '*'
  isfowner = "*"
  isfprefix = '*'
  isfcols = null
  isffilter = 'JOBID EQ' jobid.i
  Address SDSF "ISFEXEC st (prefix st_"
  isfcols = null
  Address SDSF "ISFACT ST TOKEN('"st_TOKEN.1"') PARM(NP ?) (prefix j_"
  do id = 1 to j_dsname.0
    if right(j_dsname.id,9) /= '.JESMSGLG' then iterate
    Address SDSF "ISFBROWSE ST TOKEN('"j_token.id"') (verbose"
    do isfl = isfline.0 to 1 by -1
       if pos('ICH70001I',isfline.isfl) > 0 then do
          return word(isfline.isfl,4)
          end
       end
    return userid
    end
  x = isfcalls('off')
  return userid

  /* --------------------  rexx procedure  -------------------- *
  | Name:      SortStr                                         |
  |                                                            |
  | Function:  Sorts the provided string and returns it        |
  |                                                            |
  | Syntax:    string = sortstr(string)                        |
  |                                                            |
  | Usage:     Pass any string to SORTSTR and it will return   |
  |            the string sorted                               |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            10/13/20 - Eliminate extra blank on last entry  |
  |            09/19/17 - Creation                             |
  |                                                            |
  * ---------------------------------------------------------- */
SortSTR: Procedure
  parse arg string
  do imx = 1 to words(string)-1
    do im = 1 to words(string)
      w1 = word(string,im)
      w2 = word(string,im+1)
      if w1 > w2 then do
        if im > 1
        then  lm = subword(string,1,im-1)
        else lm = ''
        rm = subword(string,im+2)
        string = lm strip(w2 w1) rm
      end
    end
  end
  return strip(string)

  /* ----------------------------------------------------- *
  | Name:  Cap1st                                         |
  |                                                       |
  | Function: Lowercase a string and then capitalize each |
  |           individual word.                            |
  |                                                       |
  | Syntax: x = cap1st(string)                            |
  |                                                       |
  | History:                                              |
  |           2024/01/31 Remove LC option (not needed)    |
  |           2021/12/14 Add exceptions                   |
  |           2021/11/29 Created by LBD                   |
  |                                                       |
  * ----------------------------------------------------- */
Cap1st: Procedure
  parse arg string
  reserved = 'DJC HSM'
  string = translate(string,"abcdefghijklmnopqrstuvwxyz",,
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  if pos(',',string) > 0
  then do
    string = translate(string,' ',',')
    first2last = 1
  end
  else first2last = 0
  len = words(string)
  do i = 1 to len
    w = word(string,i)
    if wordpos(translate(w),reserved) = 0 then do
      c = left(w,1)
      w = overlay(translate(c),w,1,1)
    end
    else do
      w = translate(w)
    end
    if i = 1
    then string = w subword(string,2)
    else do
      lw = subword(string,1,i-1)
      rw = subword(string,i+1)
      string = lw w rw
    end
  end
  if first2last = 1 then
  string = subword(string,2) word(string,1)
  return string
