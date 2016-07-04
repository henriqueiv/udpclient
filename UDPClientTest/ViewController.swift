//
//  ViewController.swift
//  UDPClientTest
//
//  Created by Pietro Degrazia on 7/3/16.
//  Copyright © 2016 PDG. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

class ViewController: UIViewController {
    
    var udpSocket:GCDAsyncUdpSocket!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let msg = "hello coordinator"
        let host = "10.0.0.255"
//        let host = "0.0.0.0"
//        let host = "192.168.33.255"
//        let host = "172.16.75.255"
        
        guard let helloData = msg.dataUsingEncoding(NSUTF8StringEncoding) else {return}
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatch_get_main_queue())

        print(getIFAddresses())
//        print(udpSocket.localPort())
//        print(udpSocket.localAddress())
//        
//        print(udpSocket.localHost_IPv4())
//        print(udpSocket.localAddress_IPv4())
//        print(udpSocket.localPort_IPv4())
//        
//        print(udpSocket.localHost_IPv6())
//        print(udpSocket.localAddress_IPv6())
//        print(udpSocket.localPort_IPv6())
//        
        
        
        do {
            try udpSocket.enableBroadcast(true)
            udpSocket.sendData(helloData, toHost: host, port: 50141, withTimeout: 10, tag: 0)
            try udpSocket.beginReceiving()
            
        } catch let error{
            print(error)
        }
    }
    
    func getIFAddresses() -> [String:String] {
        var addressesDic = [String:String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr.memory.ifa_next }
                
                let flags = Int32(ptr.memory.ifa_flags)
                var addr = ptr.memory.ifa_addr.memory
                var netMask = ptr.memory.ifa_netmask.memory
                
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                        
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        var netmask = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            if (getnameinfo(&netMask, socklen_t(netMask.sa_len), &netmask, socklen_t(netmask.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            
                                if let address = String.fromCString(hostname) {
                                    if let netMask  = String.fromCString(netmask) {
                                        addressesDic[address] = netMask
                                    }
                                }
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return addressesDic
    }
}

extension ViewController: GCDAsyncUdpSocketDelegate {
    func udpSocket(sock: GCDAsyncUdpSocket!, didSendDataWithTag tag: Int) {
        print("didSendDataWithTag -- \(tag) --")
    }
    
    func udpSocket(sock: GCDAsyncUdpSocket!, didNotSendDataWithTag tag: Int, dueToError error: NSError!) {
        print("did *NOT* SendDataWithTag -- \(tag) --")
        print(error.localizedDescription)
    }
    
    func udpSocket(sock: GCDAsyncUdpSocket!, didReceiveData data: NSData!, fromAddress address: NSData!, withFilterContext filterContext: AnyObject!) {
        let str = String(data: data, encoding: NSUTF8StringEncoding)
        print(str)
    }
    
    
}


struct NetInfo {
    // IP Address
    let ip: String
    
    // Netmask Address
    let netmask: String
    
    // CIDR: Classless Inter-Domain Routing
    var cidr: Int {
        var cidr = 0
        for number in binaryRepresentation(netmask) {
            let numberOfOnes = number.componentsSeparatedByString("1").count - 1
            cidr += numberOfOnes
        }
        return cidr
    }
    
    // Network Address
    var network: String {
        return bitwise(&, net1: ip, net2: netmask)
    }
    
    // Broadcast Address
    var broadcast: String {
        let inverted_netmask = bitwise(~, net1: netmask)
        let broadcast = bitwise(|, net1: network, net2: inverted_netmask)
        return broadcast
    }
    
    
    private func binaryRepresentation(s: String) -> [String] {
        var result: [String] = []
        for numbers in (s.characters.split {$0 == "."}) {
            if let intNumber = Int(String(numbers)) {
                if let binary = Int(String(intNumber, radix: 2)) {
                    result.append(NSString(format: "%08d", binary) as String)
                }
            }
        }
        return result
    }
    
    private func bitwise(op: (UInt8,UInt8) -> UInt8, net1: String, net2: String) -> String {
        let net1numbers = toInts(net1)
        let net2numbers = toInts(net2)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i],net2numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    private func bitwise(op: UInt8 -> UInt8, net1: String) -> String {
        let net1numbers = toInts(net1)
        var result = ""
        for i in 0..<net1numbers.count {
            result += "\(op(net1numbers[i]))"
            if i < (net1numbers.count-1) {
                result += "."
            }
        }
        return result
    }
    
    private func toInts(networkString: String) -> [UInt8] {
        return (networkString.characters.split {$0 == "."}).map{UInt8(String($0))!}
    }
}