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

            // example of parsing single messages. osc::OsckPacketListener
            // handles the bundle traversal.
            
           if( strcmp( m.AddressPattern(), "/bioniclooper1/rec" ) == 0 ){

                osc::ReceivedMessage::const_iterator arg = m.ArgumentsBegin();
                bool isRec = (arg++)->AsBool();
                if( arg != m.ArgumentsEnd() )
                    throw osc::ExcessArgumentException();
               
               if(isRec)
               {
                   // Trigger Callback on main controller to start REC
                   // DELEGATE ?
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

