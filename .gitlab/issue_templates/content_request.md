## Summary

To request a content request in the pipeline, the base job must already be in the repository.

`add the label content_request`
## Content title convention 

```
folder/job cluster version
```


* opus  = OR  whitley/EGS 
* icx-1 = GDC whitley/EGS
* gdc-1 = purley


*more than one cluster -- use "," delimiter*

e.g.

`ive-prime95/prim95 opus,icx-1,gdc-1 latest`



## When?

when does content need to run? (this does not mean it will be approved)

## Specific Pipeline

Add only if you need to run in a specific pipeline

## Nodes

Minimum number of nodes that need to run

## Knobs? Y/N 

If Y, add list of knobs to change and the default
e.g. C = Change D = Default
C - bdatEn=1,AttemptFastBootCold=0,AttemptFastBoot=0,EnableBiosSsaLoader=0
D - bdatEn=1,AttemptFastBootCold=1,AttemptFastBoot=1,EnableBiosSsaLoader=1

## Comments

If any consideration should be taken for the content