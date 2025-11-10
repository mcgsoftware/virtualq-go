---
inclusion: always
---

# Architectural Idioms for Identity

## PostgreSQL Hosting and Features
This project will use a Neon-hosted PostgreSQL 17+ for simplicity. We can change the 
hosting or database later, if needed. 

## GUID Identifier usage
This project uses a **UUID v7** for globally unique identifiers. This format is time-sortable
which is a handy capabilty over the older UUID v4 format. These identifiers can be created by 
any database or via code without worrying about id collisions later if they are merged with other
data stores. 

Anywhere a GUID can be useful (e.g. creating a new user account id or a new order) a GUID is ideal so
when we migrate the records to a central database (e.g. a data mart) the ids won't collide with
other records. 

**Native support** - Not yet in stable releases, but PostgreSQL 17 (released September 2024) added uuid_v7() function in the uuid-ossp extension.
If you're on PostgreSQL 17+, you can use it natively.

**PostgreSQL Column Storage** - PostgreSQL can store UUID v7 as a native UUID type that efficiently stores 128 bits (16 bytes)

### Programming language UUID v7 support
- Node.js: uuidv7 or uuid (v10+)
- Java: java-uuid-generator
- Go: github.com/google/uuid
- Python: uuid6 or uuid-utils packages

#### UUID v7 Example in Go
```go
package main

import (
    "fmt"
    "github.com/google/uuid"
)

func main() {
    // Generate UUID v7
    id, err := uuid.NewV7()
    if err != nil {
        panic(err)
    }
    
    fmt.Println("UUID v7:", id.String())
    // Output example: 018c8f8e-8d9a-7a3b-9f1c-2d4e5f6a7b8c
    
    // Get as bytes (for database storage)
    bytes := id[:]
    fmt.Printf("As bytes: %x\n", bytes)
    
    // Parse UUID string back to UUID type
    parsed, err := uuid.Parse(id.String())
    if err != nil {
        panic(err)
    }
    fmt.Println("Parsed:", parsed)
}
```


#### UUID v7 Example in Java

**Maven:**
```
<dependency>
    <groupId>com.github.f4b6a3</groupId>
    <artifactId>uuid-creator</artifactId>
    <version>5.3.7</version>
</dependency>
```

**Java:**

```java
import com.github.f4b6a3.uuid.UuidCreator;
import java.util.UUID;

public class UuidExample {
    public static void main(String[] args) {
        // Generate UUID v7
        UUID id = UuidCreator.getTimeOrderedEpoch();
        
        System.out.println("UUID v7: " + id.toString());
        // Output example: 018c8f8e-8d9a-7a3b-9f1c-2d4e5f6a7b8c
        
        // Get as bytes (for database storage)
        byte[] bytes = toBytes(id);
        System.out.println("As bytes: " + bytesToHex(bytes));
        
        // Parse UUID string back to UUID type
        UUID parsed = UUID.fromString(id.toString());
        System.out.println("Parsed: " + parsed);
    }
    
    // Helper to convert UUID to bytes
    private static byte[] toBytes(UUID uuid) {
        byte[] bytes = new byte[16];
        long msb = uuid.getMostSignificantBits();
        long lsb = uuid.getLeastSignificantBits();
        for (int i = 0; i < 8; i++) {
            bytes[i] = (byte) (msb >>> (8 * (7 - i)));
            bytes[8 + i] = (byte) (lsb >>> (8 * (7 - i)));
        }
        return bytes;
    }
    
    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
```


**Java JDBC with PostgreSQL example:**
```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.UUID;

public void createUser(Connection conn, String email, String password) throws SQLException {
    UUID userId = UuidCreator.getTimeOrderedEpoch();
    
    String sql = "INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)";
    try (PreparedStatement stmt = conn.prepareStatement(sql)) {
        stmt.setObject(1, userId); // PostgreSQL UUID type
        stmt.setString(2, email);
        stmt.setString(3, password);
        stmt.executeUpdate();
    }
}
```

# Customer Identity and related data

Customer related data is highly valuable for the business and this system.

All data that references a customer uses the same GUID v7 identifier so we can
carry the customer identity across desparate systems without worry of destroying
the identity of the customer in the process. 

By design, when data is cross references a customer on or belongs to customers, we ensure the customer id
is preserved (never regenerated) in all systems and databases, including analytics systems. 

# Design prioritization

Architecture and design should follow these proirities:

- Reliability > Maintainability > Performance
- Simplicity > Sophistication 
- All systems and components include observability that dovetails into an SRE strategy
- Errors and failures are always observable events
- Performance at runtime is observed via metrics, not estimated
- Leverage Gen AI as a tool to uplift code to the optimal tech stack
