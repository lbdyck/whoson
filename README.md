# Title for WHOSON

WHOSON is a TSO command, written in REXX, that will generate a report
of all, or selected, TSO and SSH users on all the systems within the SYSPLEX.

### Also report on any other address spaces
 - find *custom* and follow instructions
 - looks for the ICH70001I message in the JESMSGLG to report on the user

Will also work as an OMVS Shell command.

## Installation

Copy the exec into a library in your SYSEXEC, or SYSPROC, allocated libraries.

For use under OMVS copy the exec into OMVS and then `chmod +x whoson`.

## Dependencies:

   * SDSF REXX
   * STEMEDIT   -- Not required when running under the z/OS Unix shell
   * RACF LU command

### Notes
If the user is not authorized to issue the RACF `lu` command for the
requested userid then the name associated with the userid will be blank.
