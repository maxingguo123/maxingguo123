# MCE Tracer

The MCE Tracer uses the kernel tracing framework to capture every MCE that takes place in the system.

Typically multiple entities mcelog, edac, cec etc register with the kernel to recive MCE events that 
the kernel detects and handle them. This also means that we are at the mercy of each such entity to
decode and log (a subset of MCE events).

Using the Kernel tracing mechanism allows us to get full visibility into all MCE's even those supressed
by the event consumers.
