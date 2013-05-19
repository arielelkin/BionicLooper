#include <iostream>
#include "osc/OscReceivedElements.h"
#include "osc/OscPacketListener.h"
#include "ip/UdpSocket.h"


#define PORT 7000

class BionicOSCPacketListener : public osc::OscPacketListener {
protected:

    virtual void ProcessMessage( const osc::ReceivedMessage& m, 
                                const IpEndpointName& remoteEndpoint )
    {
        try{
            
            std::cout << "received OSC message";
            std::cout << m.AddressPattern() << std::endl;

           // REC
            //if( strcmp( m.AddressPattern(), "/1/rec" ) == 0 ){
            if( strcmp( m.AddressPattern(), "/bioniclooper1/rec" ) == 0 ){

                osc::ReceivedMessage::const_iterator arg = m.ArgumentsBegin();
                int isRec = (arg++)->AsInt32();
               
               if(isRec==1)
               {
                   // Trigger Callback on main controller to start REC
                   // DELEGATE ?
                   NSLog(@"REC");
               }

                
           }
        }catch( osc::Exception& e ){
            // any parsing errors such as unexpected argument types, or 
            // missing arguments get thrown as exceptions.
            std::cout << "error while parsing message: "
                << m.AddressPattern() << ": " << e.what() << "\n";
        }
    }
};

