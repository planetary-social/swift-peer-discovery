# Swift Peer Discovery

**How to discover peers and announce own presence in decentralised environments?**

## Usage

1. Bring the libraries to your project:

   ```swift
   import PeerDiscovery
   import Wiggling
   import WigglingBonjour
   import WigglingUserDatagramMulticast
   ```

2. Define yourself as a peer:

   ```swift
   let myself: Peer = ... 
   ```

   > **NOTE**
   >
   > Every peer must conform to the `PeerDiscoverable` protocol;
   > you might want to read more about [Peer Discoverability](TODO) to find out how these fit together.

3. Create multi-peer wiggling session using any number and variants of [Peer Discovery Engines](TODO):

   ```swift
   let wigglingSession = 
       WigglingSession<Peer>(using: [ ... ]) 
       // TODO: ^ add udp and bonjour examples
   ```

4. Initiate the session to begin noticing other peers and announcing your own presence:

   ```swift
   wigglingSession.start(announcing: myself)
   ```

5. Subscribe to the stream of discoveries:

   ```swift
   wigglingSession.discoveries.sink { (peer, reliability) in
       print("There is \(peer) with reliability \(reliability)!")
   }
   ```

   > **NOTE**
   >
   > Each delivered discovery is a pair containing recognized `Peer` and its own  `PeerNetworkingReliability`;
   > the article about [Measuring Peer-to-Peer Connection Reliability](TODO) describes in detail how the reliability is being calculated, 
   > as well as tips on how to use such reliability metrics to maximize the flow of information in your app.

