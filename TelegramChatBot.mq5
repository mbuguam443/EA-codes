#property strict

input string BotToken = "8685310495:AAGbmwqgdN81vrifE8ImmIzVsor9iDvr4Tk";
input string ChatID   = "1322296326";
long last_update_id = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(5);
   SendTelegramMessage("ChatBot EA started.\n Command:\n balance"+_Symbol+"\n equity"+_Symbol+"\n screenshot"+_Symbol+"\n help");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTick()
{
}
//+------------------------------------------------------------------+
bool SendTelegramMessage(string text)
{
   string url=
      "https://api.telegram.org/bot"+
      BotToken+
      "/sendMessage";

   string data=
      "chat_id="+ChatID+
      "&text="+text;

   char post[];
   char result[];

   StringToCharArray(data,post);

   string headers=
      "Content-Type: application/x-www-form-urlencoded\r\n";

   string response_headers;

   ResetLastError();

   int res=WebRequest(
      "POST",
      url,
      headers,
      5000,
      post,
      result,
      response_headers
   );

   if(res==-1)
   {
      Print("Error: ",GetLastError());
      return(false);
   }

   Print("Telegram response: ",CharArrayToString(result));

   return(true);
}


void OnTimer()
{
   CheckTelegram();
}

void CheckTelegram()
{
   string url =
      "https://api.telegram.org/bot" +
      BotToken +
      "/getUpdates?offset=" +
      IntegerToString((int)(last_update_id + 1));

   uchar data[];
   uchar result[];
   string response_headers;

   ResetLastError();

   int res = WebRequest(
      "GET",
      url,
      "",
      5000,
      data,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest Error: ", GetLastError());
      return;
   }

   string json = CharArrayToString(result);

   //Print("Telegram JSON:");
   //Print(json);

   ProcessMessage(json);
}
void ProcessMessage(string json)
{
   // Find update_id
   int pos = StringFind(json, "\"update_id\":");

   if(pos >= 0)
   {
      pos += StringLen("\"update_id\":");

      string update_str = "";

      while(pos < StringLen(json))
      {
         ushort ch = StringGetCharacter(json, pos);

         if(ch >= '0' && ch <= '9')
            update_str += CharToString((uchar)ch);
         else
            break;

         pos++;
      }

      if(update_str != "")
         last_update_id = (long)StringToInteger(update_str);
   }

   // Process commands
   if(StringFind(json, "\"text\":\"balance"+_Symbol+"\"") >= 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      SendTelegramMessage(
         "Balance = " +
         DoubleToString(balance, 2)
      );
   }

   if(StringFind(json, "\"text\":\"equity"+_Symbol+"\"") >= 0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      SendTelegramMessage(
         "Equity = " +
         DoubleToString(equity, 2)
      );
   }
   if(StringFind(json, "\"text\":\"screenshot"+_Symbol+"\"") >= 0)
   {
      TakeScreenshot();
      SendTelegramMessage("Screenshot captured.");
      SendPhotoToTelegram("chart.png");
      
   }
   if(StringFind(json, "\"text\":\"help\"") >= 0)
   {
      
      SendTelegramMessage("ChatBot EA started.\n Command:\n balance"+_Symbol+"\n equity"+_Symbol+"\n screenshot"+_Symbol+" ");
      
   }
}
bool TakeScreenshot()
{

   long chart_id = ChartFirst();

   while(chart_id != -1)
   {
      Print("ID=", chart_id,
            " Symbol=", ChartSymbol(chart_id));
   
      chart_id = ChartNext(chart_id);
   }

   string file_name = "chart.png";
   
   long my_id = 134257605198610781;

   bool ok = ChartScreenShot(
      0,          // current chart
      file_name,
      1280,
      720
   );

   if(ok)
      Print("Screenshot saved");
   else
      Print("Screenshot failed");

   return ok;
}

bool SendPhotoToTelegram(string file_name)
{
   // Read image
   int handle = FileOpen(file_name, FILE_READ | FILE_BIN);

   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open file: ", file_name);
      return false;
   }

   int file_size = (int)FileSize(handle);

   uchar image[];
   ArrayResize(image, file_size);

   FileReadArray(handle, image);
   FileClose(handle);

   string boundary = "----MQL5TelegramBoundary";

   string part1 =
      "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n" +
      ChatID + "\r\n" +
      "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"photo\"; filename=\"chart.png\"\r\n" +
      "Content-Type: image/png\r\n\r\n";

   string part2 =
      "\r\n--" + boundary + "--\r\n";

   uchar body[];

   uchar p1[];
   uchar p2[];

   StringToCharArray(part1, p1);
   StringToCharArray(part2, p2);

   int total =
      ArraySize(p1)-1 +
      ArraySize(image) +
      ArraySize(p2)-1;

   ArrayResize(body, total);

   int pos = 0;

   // Part 1
   for(int i=0; i<ArraySize(p1)-1; i++)
      body[pos++] = p1[i];

   // Image
   for(int i=0; i<ArraySize(image); i++)
      body[pos++] = image[i];

   // Part 2
   for(int i=0; i<ArraySize(p2)-1; i++)
      body[pos++] = p2[i];

   string headers =
      "Content-Type: multipart/form-data; boundary=" +
      boundary + "\r\n";

   uchar result[];
   string response_headers;

   string url =
      "https://api.telegram.org/bot" +
      BotToken +
      "/sendPhoto";

   ResetLastError();

   int res = WebRequest(
      "POST",
      url,
      headers,
      10000,
      body,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest Error: ", GetLastError());
      return false;
   }

   string response = CharArrayToString(result);

   Print("Telegram Response:");
   Print(response);

   return true;
}