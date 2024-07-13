# Title for WHOSON

`WHOSON` is a TSO command, written in REXX, that will generate a report
of all, or selected, TSO and SSH users on all the systems within the SYSPLEX.
Will also report on zOSMF users (which includes Zowe Explorer users).

*Note:* the system level and IPL date and time are also reported for each LPAR.

### Also report on any other address spaces
 - find *custom* and follow instructions
 - looks for the `ICH70001I` message in the JESMSGLG to report on the user

Will also work as an OMVS Shell command and has been included as
`whoson.rex` in the git distribution for that purpose.

## Installation

Copy the exec into a library in your `SYSEXEC`, or `SYSPROC`, allocated
libraries.

For use under OMVS copy the `whoson.rex` exec into an OMVS
directory in your `PATH` and then `chmod +x whoson` and then tag as
IBM-1047 (`chtag -tc 1047`).

## Dependencies:

   * SDSF REXX
   * STEMEDIT   -- Not required when running under the z/OS Unix shell
   * RACF LU command

### Notes
If the user is not authorized to issue the RACF `lu` command for the
requested userid then the name associated with the userid will be blank.
