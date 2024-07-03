# hexPDS
An ATProto PDS in Elixir/Rust

## The current state of things

As of right now, this is not in a state where it can be used yet.

Statuses for various components:
   - Identity resolution - more or less complete
   - cryptographic key generation, signing, and validation - complete (secp256k1 only)
   - DID PLC operation signing (CBOR) - creates complete, probably easy to add updates from here
   - transforming between JSON and CBOR - complete
   - Lexicon validation - not currently planned
   - MST - started
   - Firehose - not started
   - TID generation (and decoding!!) - complete
   - blobs - getBlob, listBlobs - uploadBlob held up by auth/jwt
   - service proxy header - parses and finds service URL
   - inter-service auth - need JWT stuff
   - preferences - almost ready to start
   - anything moderation-related - not started



