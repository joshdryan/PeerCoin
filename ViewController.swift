//
//  ViewController.swift
//  PeerCoin
//
//  Created by Josh Ryan on 2/25/18.
//

import MultipeerConnectivity
import UIKit


// Block object can be encoded for transfer
class Block: NSObject, NSCoding {
    var index: Int
    var timestamp: Date
    var data: [String:String]
    var previousHash: Int
    
    init(index: Int, timestamp: Date, data: [String:String], previousHash: Int) {
        self.index = index
        self.timestamp = timestamp
        self.data = data
        self.previousHash = previousHash
    }
    
    required convenience init?(coder adecoder: NSCoder) {
        let timestamp = adecoder.decodeObject(forKey: "timestamp") as! Date
//        let index = adecoder.decodeObject(forKey: "index") as! Int
//        let timestamp = adecoder.decodeObject(forKey: "timestamp") as! Date
        let data = adecoder.decodeObject(forKey: "data") as! [String:String]
//        let previousHash = adecoder.decodeObject(forKey: "previousHash") as! Int
    
        self.init(index: adecoder.decodeInteger(forKey: "index"), timestamp:timestamp, data:data, previousHash:adecoder.decodeInteger(forKey: "previousHash"))
    }
    
    
    func encode(with acoder: NSCoder) {
        acoder.encodeCInt(Int32(index), forKey: "index")
        acoder.encode(timestamp, forKey: "timestamp")
        acoder.encode(data, forKey: "data")
        acoder.encode(previousHash, forKey: "previousHash")
    }
}

class ViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {
    var blockchain: [Block] = []
    var wallet = 0
    
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        title = "PeerCoin"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))
//        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showCoinPrompt))
        
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = nil
    }
    
    
//    Simple proof of work, increments by 9 each time a new block is mined.
    func proofOfWork(last_proof: String) -> String{
        var increment: Int = Int(last_proof)!
        increment += 1
        while (increment  % 9 != 0){
            increment += 1
            
        }
        return String(increment)
        
    }
    
//    Function to create the first block
    @objc func createGenesis() {
        blockchain = []
        wallet = 1
        let Block1 = Block(index: 0,timestamp: Date(), data: ["proof-of-work":"9", "transactions":"None"], previousHash: 0)
        blockchain.append(Block1)
        print("Connected: \(Block1)")
        print(Block1.index)
        print(blockchain)
        let x = blockchain.description
        let bc = UIAlertController(title: "Succesfully Initialized BlockChain", message: x, preferredStyle: .actionSheet)
        bc.addAction(UIAlertAction(title: "Close", style: .default, handler: closeAction))
        present(bc,animated: true)
    }
    
//    Allow user to interact with the blockchain
    @objc func showCoinPrompt() {
        print(mcSession)
        if mcSession != nil {
        let ac = UIAlertController(title: "What would you like to do?", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Mine Coin", style: .default, handler: mineCoin))
        ac.addAction(UIAlertAction(title: "View Blockchain", style: .default, handler: showBlockchain))
        ac.addAction(UIAlertAction(title: "View Wallet", style: .default, handler: showWallet))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
        }
        else{
            let ac = UIAlertController(title: "You Must Host or Join a network first.", message: nil, preferredStyle: .actionSheet)
            ac.addAction(UIAlertAction(title: "Close", style: .default, handler: closeAction))

            
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(ac, animated: true)
        }
    }
    
//    Allow user to mine coin once connected
    @objc func mineCoin(action: UIAlertAction) {
        let last_block = blockchain[blockchain.count-1]
        let last_proof1 = last_block.data["proof-of-work"]
        let proof = proofOfWork(last_proof: last_proof1!)
        print(last_proof1!)
        print(proof)
        let new_block_data = ["proof-of-work":proof,"transactions":"None"]
        var new_block_index = last_block.index
        new_block_index += 1
        let mined_block = Block(index: new_block_index,timestamp: Date(), data: new_block_data, previousHash: 0)
        blockchain.append(mined_block)
        
        wallet += 1
        
        
        print("Connected: \(mined_block)")
        print(blockchain)
        let x = blockchain.description
      
        for i in blockchain{
            print(i.data)
            let data = NSKeyedArchiver.archivedData(withRootObject: Block(index: i.index, timestamp: i.timestamp, data: i.data, previousHash: i.previousHash))
            guard let block: Block = NSKeyedUnarchiver.unarchiveObject(with: data) as! Block? else { return }
            print(block)
            print(block.index)
        }
        
        syncBlockchain()
        
        let bc = UIAlertController(title: "Succesfully Mined New Block!", message: x, preferredStyle: .actionSheet)
        bc.addAction(UIAlertAction(title: "Close", style: .default, handler: closeAction))
        present(bc,animated: true)
    }
    
//    *important* When this is called it will send the up to date blockchain to all other nodes.
    func syncBlockchain(){
        if mcSession.connectedPeers.count > 0 {
            for i in blockchain{
                let data = NSKeyedArchiver.archivedData(withRootObject: Block(index: i.index, timestamp: i.timestamp, data: i.data, previousHash: i.previousHash))
                do {
                    try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    present(ac, animated: true)}
            }
        }
    }
    
    // Display blockchain contents
    @objc func showBlockchain(action: UIAlertAction) {
        var blockchain_string = "["
        for i in blockchain{
            blockchain_string = blockchain_string + "{"
            blockchain_string = blockchain_string + "index: " + i.index.description
            blockchain_string = blockchain_string + ", timestamp: " + i.timestamp.description
            blockchain_string = blockchain_string + ", data: " + i.data.description
            blockchain_string = blockchain_string + ", previousHash: " + i.previousHash.description + "}, "
        }
        blockchain_string = blockchain_string + "]"
        let x = blockchain_string
        let bc = UIAlertController(title: "Most Recent Blockchain:", message: x, preferredStyle: .actionSheet)
        bc.addAction(UIAlertAction(title: "Close", style: .default, handler: closeAction))
        present(bc,animated: true)
    }
    
    @objc func showWallet(action: UIAlertAction) {
        let x = wallet.description
        let bc = UIAlertController(title: "Current Wallet Balance:", message: x, preferredStyle: .actionSheet)
        bc.addAction(UIAlertAction(title: "Close", style: .default, handler: closeAction))
        present(bc,animated: true)
    }
    
    
    func closeAction(action: UIAlertAction) {
        print("Success")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @objc func showConnectionPrompt() {
        let ac = UIAlertController(title: "Connect or host a blockchain", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
        ac.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func startHosting(action: UIAlertAction) {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "hws-project25", discoveryInfo: nil, session: mcSession)
        mcAdvertiserAssistant.start()
        
        createGenesis()
    }
    
    func joinSession(action: UIAlertAction) {
        blockchain = []
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        let mcBrowser = MCBrowserViewController(serviceType: "hws-project25", session: mcSession)
        mcBrowser.delegate = self
        present(mcBrowser, animated: true)
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case MCSessionState.connected:
            print("Connected: \(peerID.displayName)")
            
//            Once connected, request a blockchain sync
            let sync = Block(index: 0,timestamp: Date(), data: ["proof-of-work":"syncBlockchain", "transactions":"None"], previousHash: 0)
            
            if mcSession.connectedPeers.count > 0 {

                let data = NSKeyedArchiver.archivedData(withRootObject: sync)
                do {
                    try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                    present(ac, animated: true)}
                }
            
            
            
        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")
            
        case MCSessionState.notConnected:
            print("Not Connected: \(peerID.displayName)")
        }
    }
    
//    Recieve data
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        print(data)
        guard let block: Block = NSKeyedUnarchiver.unarchiveObject(with: data) as! Block? else { return }
        if block.data["proof-of-work"] == "syncBlockchain"{
            syncBlockchain()
        }
        if block.index >= blockchain.count{
            blockchain.append(block)
        }
    }
    
}

