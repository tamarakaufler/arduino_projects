/*--------------------------------------------------------------
  Program:      hackathon

  Description:  Arduino web server that responds to client requests by
                lighting up LEDs, starting a bubble machine etc.
                Based on below mentioned references.
  
  Hardware:     Arduino Uno and official Arduino Ethernet
                shield. Should work with other Arduinos and
                compatible Ethernet shields.
  
  References:   - 
                  W.A. Smith, http://startingelectronics.com
                  based on WebServer example by David A. Mellis and 
                  modified by Tom Igoe
 
  Date:         2 March 2013
  Modified:     14 June 2013
 
  Adjusted for Photobox Hackathon 2015 by Tamara Kaufler, 27/04/2015  
--------------------------------------------------------------*/

#include <SPI.h>
#include <Ethernet.h>
#include <LiquidCrystal.h>

// size of buffer used to capture HTTP requests
#define REQ_BUF_SZ   40
#define REQ_INFO_SZ  30

// MAC address from Ethernet shield sticker under board
byte mac[] = { 0x00, 0xAA, 0xBB, 0xCC, 0xDE, 0x02 };

IPAddress ip(192,168,162,88);   // IP address, may need to change depending on network

EthernetServer server(80);       // create a server at port 80
char HTTP_req[REQ_BUF_SZ] = {0}; // buffered HTTP request stored as null terminated string
char req_index = 0;              // index into HTTP_req buffer

//char pin4twitter = 8;
//char pin4email   = 9;

char pin4bubble  = 7;

LiquidCrystal lcd(9, 8, 5, 4, 3, 2);

char pin4hipchat  = 6;

//char req_info[REQ_INFO_SZ] = {'p','h','o','t','o','b','o','x', 0};
char req_info[REQ_INFO_SZ] = {0};
char req_info_index = 0;

void setup()
{
    // disable Ethernet chip
    pinMode(10, OUTPUT);
    digitalWrite(10, HIGH);

    pinMode(pin4hipchat, OUTPUT);    
    pinMode(pin4hipchat, LOW);
    pinMode(pin4bubble, OUTPUT);    
    pinMode(pin4bubble, LOW);
    
    Serial.begin(9600);       // for debugging

    lcd.begin(16, 2);
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print("hello, world!");
    delay(1000);

    Ethernet.begin(mac, ip);  // initialize Ethernet device
    server.begin();           // start to listen for clients
    
//    pinMode(pin4bubble, HIGH);
//    delay(2000);
//    pinMode(pin4bubble, LOW);
    
}

void loop()
{
    EthernetClient client = server.available();  // try to get client

    if (client) {  // is a client connected?
        boolean currentLineIsBlank = true;
        
        // yes, we have a client!
        while (client.connected()) {
          
            // start the party!!
            if (client.available()) {   // client data available to read
            
                char c = client.read(); // read 1 byte (character) from client
                // buffer first part of HTTP request in HTTP_req array (string)
                // leave last element in array as 0 to null terminate string (REQ_BUF_SZ - 1)
                if (req_index < (REQ_BUF_SZ - 1)) {
                    HTTP_req[req_index] = c;          // save HTTP request character
                    req_index++;
                }
                // last line of client request is blank and ends with \n
                // respond to client only after last line received
                if (c == '\n' && currentLineIsBlank) {
                    // send a standard http response header
                    client.println("HTTP/1.1 200 OK");
                    client.println("Content-Type: text");
                    client.println("Connnection: close");
                    client.println();
  
                    // open requested web page file
                    if (StrContains(HTTP_req, "GET / ")
                                 || StrContains(HTTP_req, "GET /twitter")) {
                        
                        client.println("Event - twitter");

                        if (StrContains(HTTP_req, "?")) {
                          // get the search term
                          char index = 0;
                          char length = (strlen(HTTP_req) - 13);

                          for (int i = 0; i < length; i++) {
                              if (HTTP_req[i+13] == ' ' && 
                                  HTTP_req[i+14] == 'H' && 
                                  HTTP_req[i+15] == 'T' && 
                                  HTTP_req[i+16] == 'T') { 

                                  req_info[index] = 0;
                                  client.println(req_info);

                                  req_index = 0;
                                  StrClear(HTTP_req, REQ_BUF_SZ);
                                  StrClear(req_info, REQ_INFO_SZ);
                                  break; 
                              }
                              req_info[index] = HTTP_req[i+13];
                              //client.println(req_info[index]);
                              index++;
                          }

                        }

                        // light up and display the tweet count on LCD
                        //digitalWrite(pin4twitter, HIGH);

                        lcd.clear();
                        lcd.setCursor(0,0);
                        //lcd.print("TWEETING!");
                        lcd.print("47 tweets");
                        //lcd.setCursor(0,1);

                        delay(5000);
                        //digitalWrite(pin4twitter, LOW);

                        lcd.clear();
                    }
                    else if (StrContains(HTTP_req, "GET /email")) {
                        
                        client.println("Event - email");
                        client.stop();
                        
                        lcd.clear();
                        lcd.setCursor(0,0);
                        lcd.print("EMAINING!");                  
                        
                        // start the Bubble machine
                        digitalWrite(pin4bubble, HIGH);
                        delay(5000);
                        digitalWrite(pin4bubble, LOW);
                        
                    }
                    else if (StrContains(HTTP_req, "GET /hipchat")) {
                                              
                        lcd.clear();
                        lcd.setCursor(0,0);
                        lcd.print("HIPCHAT!"); 
                        
                        digitalWrite(pin4hipchat, HIGH);
                        delay(5000);
                        digitalWrite(pin4hipchat, LOW);
                    }

                    // reset buffer index and all buffer elements to 0
                    req_index = 0;
                    StrClear(HTTP_req, REQ_BUF_SZ);
                    StrClear(req_info, REQ_INFO_SZ);
                    break;
                }
                // every line of text received from the client ends with \r\n
                if (c == '\n') {
                    // last character on line of received text
                    // starting new line with next character read
                    currentLineIsBlank = true;
                } 
                else if (c != '\r') {
                    // a text character was received from client
                    currentLineIsBlank = false;
                }
             
            } // end if (client.available())
        } // end while (client.connected())
        
        delay(1);      // give the web browser time to receive the data
        client.stop(); // close the connection
        
    } // end if (client)
}

// sets every element of str to 0 (clears array)
void StrClear(char *str, char length)
{
    for (int i = 0; i < length; i++) {
        str[i] = 0;
    }
}

// searches for the string sfind in the string str
// returns 1 if string found
// returns 0 if string not found
char StrContains(char *str, char *sfind)
{
    char found = 0;
    char index = 0;
    char len;

    len = strlen(str);
    
    if (strlen(sfind) > len) {
        return 0;
    }
    while (index < len) {
        if (str[index] == sfind[found]) {
            found++;
            if (strlen(sfind) == found) {
                return 1;
            }
        }
        else {
            found = 0;
        }
        index++;
    }

    return 0;
}

