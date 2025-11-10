# VirtualQ 

VirtualQ is a large kiro project multiple apps, database and services. Turns out that it can't handle a solutions project, 
so this was scaled back in scope. 

This is the services and database part of the solution. 

It does contain some domain requirements information, especially the test case tenants: starbucks and dmv

## Go app

build 
```bash
go build -o virtualq
```

### Go service dependencies

Create dependencies
```bash
 go get "github.com/jackc/pgx/v5/pgxpool"

```

