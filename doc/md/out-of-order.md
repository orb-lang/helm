# Out of Order: System Design in the Weird Hardware Era

talking points:


- All machines are weird until proven otherwise


- In important cases, this is just proven


  -  Meltdown, Spectre: The most basic contract is "do not follow opposite
     conditional branches", and this is violated, and it turns out that
     matters.


  -  Exploits on microSD, GSM band, other actors with arbitrary access to
     system memory.  "Every circuit is either Turing Complete or aspires
     to be".


-  Successes:


  -  ASICs for hash mining. Pure pipeline-fed number crunching. Notable for
     what it cannot do.


  -  Greenarrays: quirky, but if there was ever a chip that fulfills its
     written specification, it's one that was synthesized from written
     Forth...


     Admittedly weird hardware! But is it _weird_ weird hardware...