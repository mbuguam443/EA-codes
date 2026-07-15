#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

input string BotToken = "8685310495:AAGbmwqgdN81vrifE8ImmIzVsor9iDvr4Tk";
input string ChatID   = "1322296326";
input int   TeleCycleSeconds=4;
long last_update_id = 0;

input double StartingCapital=100;
input double AllowedDD=21; //AllowedDD in %
input double PercentReduce=0.5;
input double FinishLine=108050;

input double DailyProfitTarget=200;
input double DailyLossStop=200;

double profitClosed;

//+------------------------------------------------------------------+
//|   Graph code                                                               |
//+------------------------------------------------------------------+
#property script_show_inputs
#include <Canvas/Canvas.mqh>

double running_profit = 0;
double cumulative_profit_array[];

double peak_equity = 0;
double peak_dd = 0;


double min_profit = 0;
double max_profit = 0;
bool dashboard_visible = true;

int W = 650;
int H = 300;

CCanvas canvas;
string CANVAS_NAME = "DASH_CANVAS";
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


input group "Trade Setting"
static input ulong InpMagicNumber=3763342;
input double LowestRiskAmount=3.0;

enum LOT_MODE_ENUM{
  LOT_MODE_FIXED,  // fixed lots
  LOT_MODE_MONEY,  //lot based on money
  LOT_MODE_PCT_ACCOUNT //lots based on percent of account (lot must be %)
};
input LOT_MODE_ENUM InpLotMode=LOT_MODE_PCT_ACCOUNT; //lot mode

input double InpLots=0.01;       //lots / money/ %
input int SlPoints=200;
input int TpPoint=600;


input group "Fast Setting"
input int FastPeriod=21;
input ENUM_MA_METHOD FastMethod=MODE_LWMA;
input ENUM_APPLIED_PRICE FastPrice=PRICE_CLOSE;
input ENUM_TIMEFRAMES FastTimeFrame=PERIOD_CURRENT;

input group "Slow Setting"
input int SlowPeriod=150;
input ENUM_MA_METHOD SlowMethod=MODE_LWMA;
input ENUM_APPLIED_PRICE SlowPrice=PRICE_CLOSE;
input ENUM_TIMEFRAMES SlowTimeFrame=PERIOD_CURRENT;

int handleFastHMA;
int handleSlowHMA;
int totalBars;

bool enableEA=true;
double newPercentLot;
double peak_dd_percent=0.0;
//chat variabe

double riskincrement=0;
double profitpercenttarget=0;
double losspercentlimit=0;
double maxdrawdown=0;
double startCapital=0;
double finishProfit=0;
bool   activeNews=true;
bool   enoughsignal=true;

string help="HMAFS ChatBot "+_Symbol+" EA started \n Account: "+AccountInfoString(ACCOUNT_NAME)+
                          "\n MagicNumber:"+InpMagicNumber+
                          "\nServer: " + AccountInfoString(ACCOUNT_SERVER)+
                           ".\n Command:\n balance"+
                           "\n equity"+
                           "\n screenshothmafs"+
                           "\n enoughsignal"+
                           "\n News Alert: "+activeNews+
                           "\n screenshot"+
                           "\n magicno"+
                           " \n help "+
                           "\n status" + IntegerToString(InpMagicNumber)+
                           "\n enable"+InpMagicNumber+
                           "\n disable"+
                           "\n enablenews"+
                           "\n disablenews"+InpMagicNumber+
                           "\n closeposition"+InpMagicNumber+
                           "\n newPercentLot"+InpMagicNumber+
                           "\n riskincrement"+InpMagicNumber+
                           "\n profitpercenttarget"+InpMagicNumber+
                           "\n losspercentlimit"+InpMagicNumber+
                           "\n maxdrawdown"+InpMagicNumber+
                           "\n startCapital"+InpMagicNumber+
                           "\n finishProfit"+InpMagicNumber+    
                            "\n enable"+InpMagicNumber+
                            "\n===========all bot are active==>"+enableEA;

int OnInit()
  {
    
    EventSetTimer(5);
    
   profitClosed=CalculateDailyProfitClosed(); 
    
   totalBars=iBars(_Symbol,PERIOD_CURRENT);
   handleFastHMA=iCustom(_Symbol,FastTimeFrame,"Market/HMA Color with Alerts MT5.ex5","",FastPeriod,FastMethod,FastPrice,"",false,false,false,false,"","",false);
   handleSlowHMA=iCustom(_Symbol,SlowTimeFrame,"Market/HMA Color with Alerts MT5.ex5","",SlowPeriod,SlowMethod,SlowPrice,"",false,false,false,false,"","",false);
   
   if(handleFastHMA==INVALID_HANDLE){
     Print("Fast Indicator Failed");
    return INIT_FAILED;
   }else{
    Print("Fast ",FastPeriod," loaded successfully");
   }
   if(handleSlowHMA==INVALID_HANDLE){
     Print("Slow Indicator Failed");
    return INIT_FAILED;
   }else{
    Print("Slow ",SlowPeriod," loaded successfully");
   }
   //authorization of the Robot Expert advisor
   //Authorization();
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   
   //intialize input for chat
   newPercentLot=InpLots;
   riskincrement=PercentReduce;
   profitpercenttarget=DailyProfitTarget;
   losspercentlimit=DailyLossStop;
   maxdrawdown=AllowedDD;
   startCapital=StartingCapital;
   finishProfit=FinishLine;
   
   //send to telegram
   SendTelegramMessage(help);
   
   //graph code 
   canvas.CreateBitmapLabel(
      0, 0,
      "DASH",
      W,
      H,
      COLOR_FORMAT_ARGB_NORMALIZE
   );
   

   BuildHistory();

   Draw();
   //end graph code
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   canvas.Destroy();
      ObjectsDeleteAll(0, "DASH");
      ChartRedraw();
   
  }
  


bool SendTelegramMessage(string text)
{

    // Don't send Telegram messages while backtesting
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Strategy Tester detected - Telegram message skipped.");
      return(true);
   }
   
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
   // Don't send Telegram messages while backtesting
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Strategy Tester detected - Telegram message skipped.");
      return;
   }

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
   if(StringFind(json, "\"text\":\"balance\"") >= 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      SendTelegramMessage(
         AccountInfoString(ACCOUNT_NAME)+" Balance = " +
         DoubleToString(balance, 2)
      );
   }

   if(StringFind(json, "\"text\":\"equity\"") >= 0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      SendTelegramMessage(
         AccountInfoString(ACCOUNT_NAME)+" Equity = " +
         DoubleToString(equity, 2)
      );
   }
   if(StringFind(json, "\"text\":\"magicno\"") >= 0)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      SendTelegramMessage(
         AccountInfoString(ACCOUNT_NAME)+" "+_Symbol+" Magicno = " +
         IntegerToString(InpMagicNumber)+" status: "+enableEA
      );
   }
   
   string cmd = "status" + IntegerToString(InpMagicNumber);

   if(StringFind(json, cmd) >= 0)
   {
      string msg =
         "ChatBot "+_Symbol+" EA Chart \n Account: "+AccountInfoString(ACCOUNT_NAME)+
         "\n MagicNumber:"+InpMagicNumber+
         "\nServer: " + AccountInfoString(ACCOUNT_SERVER)+
         "enableEA: " + (enableEA ? "true" : "false") + "\n"
         "newPercentLot: " + DoubleToString(newPercentLot, 2) + "\n"
         "running_profit: " + DoubleToString(running_profit, 2) + "\n"
         "peak_equity: " + DoubleToString(peak_equity, 2) + "\n"
         "peak_dd: " + DoubleToString(peak_dd, 2) + "\n"
         "peak_dd_percent: " + DoubleToString(peak_dd_percent, 2) + "\n"
         "riskincrement: " + DoubleToString(riskincrement, 2) + "\n"
         "profitpercenttarget: " + DoubleToString(profitpercenttarget, 2) + "\n"
         "losspercentlimit: " + DoubleToString(losspercentlimit, 2) + "\n"
         "maxdrawdown: " + DoubleToString(maxdrawdown, 2) + "\n"
         "startCapital: " + DoubleToString(startCapital, 2) + "\n"
         "finishProfit: " + DoubleToString(finishProfit, 2);
         
      SendTelegramMessage(msg);
      
      TakeScreenshot();
      SendTelegramMessage(AccountInfoString(ACCOUNT_NAME)+" Screenshot captured.");
      SendPhotoToTelegram("chart.png");
   }
   if(StringFind(json, "\"text\":\"screenshothmafs\"") >= 0)
   {
      TakeScreenshot();
      SendTelegramMessage(AccountInfoString(ACCOUNT_NAME)+" Screenshot captured.");
      SendPhotoToTelegram("chart.png");
      
   }
   
   if(StringFind(json, "\"text\":\"enoughsignal\"") >= 0)
   {
      enoughsignal=!enoughsignal;
     
      SendTelegramMessage("Signal  activation: "+enoughsignal);
      
   }
   if(StringFind(json, "\"text\":\"help\"") >= 0)
   {
      string account_name = AccountInfoString(ACCOUNT_NAME);
      SendTelegramMessage(help);
      
   }
   if(StringFind(json, "\"text\":\"disable"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       enableEA=false;
      SendTelegramMessage("EA disabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"enable"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       enableEA=true;
      SendTelegramMessage("EA enabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"disablenews\"") >= 0)
   {
       activeNews=false;
      SendTelegramMessage("News disabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"enablenews\"") >= 0)
   {
       activeNews=true;
      SendTelegramMessage("New enabled successfully");
      Draw();
   }
   if(StringFind(json, "\"text\":\"closeposition"+IntegerToString(InpMagicNumber)+"\"") >= 0)
   {
       ClosePosition(0);
       ClosePosition(1);
      SendTelegramMessage(_Symbol+"Position Closed successfully No position ");
      Draw();
   }
  
       
    string magic = IntegerToString(InpMagicNumber);

       UpdateDoubleSetting(
         json,
         "finishProfit" + magic,
         "finishProfit",
         finishProfit
      );
      
      UpdateDoubleSetting(
         json,
         "newPercentLot" + magic,
         "newPercentLot",
         newPercentLot
      );
      
      UpdateDoubleSetting(
         json,
         "riskincrement" + magic,
         "riskincrement",
         riskincrement
      );
      
      UpdateDoubleSetting(
         json,
         "profitpercenttarget" + magic,
         "profitpercenttarget",
         profitpercenttarget
      );
      
      UpdateDoubleSetting(
         json,
         "losspercentlimit" + magic,
         "losspercentlimit",
         losspercentlimit
      );
      
      UpdateDoubleSetting(
         json,
         "maxdrawdown" + magic,
         "maxdrawdown",
         maxdrawdown
      );
      
      UpdateDoubleSetting(
         json,
         "startCapital" + magic,
         "startCapital",
         startCapital
      ); 
   
        
  
}
bool UpdateDoubleSetting(string json,
                         string command,
                         string name,
                         double &variable)
   {
      if(StringFind(json, command + "=") < 0)
         return false;
   
      string value = ExtractCommandValue(json, command);
   
      if(value == "")
         return false;
   
      variable = StringToDouble(value);
   
      SendTelegramMessage(
         _Symbol + " " + name +
         " set to " +
         DoubleToString(variable, 2)
      );
   
      Draw();
   
      return true;
   }
   
   string ExtractCommandValue(string text, string command)
   {
      int pos = StringFind(text, command + "=");
   
      if(pos < 0)
         return "";
   
      int start = pos + StringLen(command) + 1;
   
      int end = StringFind(text, "\"", start);
   
      if(end < 0)
         return "";
   
      return StringSubstr(text, start, end - start);
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
void BlockBlow()
{
  if(AccountInfoDouble(ACCOUNT_EQUITY) <5)
    {
      int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         
         if(PositionSelectByTicket(ticket))
           {
              trade.PositionClose(ticket);
           }
      }
    }
}
void OnTick()
  {
  
   if(!enableEA)
     {
       ClosePosition(0);
       ClosePosition(1);
       return;
     }
   
    double accountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
     double accountEquity=AccountInfoDouble(ACCOUNT_EQUITY);
     double profitOpen=accountEquity-accountBalance;
     double profitDay=profitOpen+profitClosed;
     
     
     Comment(" Profit Open: ",DoubleToString(profitOpen,2),
             " Profit Closed: ",DoubleToString(profitClosed,2),
             " Profit for the  Day: ",DoubleToString(profitDay,2),
             " Target Profit: ",DoubleToString(DailyProfitTarget,2),
             " Stop Loss : ",DoubleToString(DailyLossStop,2));
             
    if(profitDay >DailyProfitTarget || profitDay <DailyLossStop)
      {
        for(int i=PositionsTotal()-1;i>=0;i--)
          {
            ulong posTicket=PositionGetTicket(i);
            trade.PositionClose(posTicket);
            Print("Certain target reached: DailyProfitTarget: ",DailyProfitTarget," DailyLossStop: ",DailyLossStop);
          }
      } 
  
  
    //BlockBlow();
   int bars=iBars(_Symbol,PERIOD_CURRENT);
   if(totalBars!=bars)
     {
      totalBars=bars;
      
      
      int cntBuy=0,cntSell=0;
      Countpositions(cntBuy,cntSell);
      
      if(cntBuy>0 )
          {
            //trailing(true);
            UpdateStopLoss(SlPoints);
          }
        if(cntSell>0)
          {
           //trailing(false);
           UpdateStopLoss(SlPoints);
          }
      
      double fastBuffer[],slowBuffer[];
      
      CopyBuffer(handleFastHMA,0,1,3,fastBuffer);
      CopyBuffer(handleSlowHMA,0,1,2,slowBuffer);
      
      
      
      if(slowBuffer[1] > slowBuffer[0])
        {
          Print("Up Trend");
          if(cntSell>0)
           {
                 ClosePosition(false);
           }
           //Detecting Buy
          if(cntBuy==0 &&fastBuffer[2]>fastBuffer[1] && fastBuffer[1] <fastBuffer[0])
            {
              Print("We Buy Now ");
              if(enoughsignal)
                {
                 SendTelegramMessage("HMAFS We Buy Now");
                 TakeScreenshot();
                 SendPhotoToTelegram("chart.png");
                 SendTelegramMessage(AccountInfoString(ACCOUNT_NAME)+" Screenshot captured.");
                }
              
              
              
              double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
              double tp=TpPoint==0?0: entry +TpPoint*_Point;
              double sl=SlPoints==0?fastBuffer[0]:entry-SlPoints*_Point;
              entry=NormalizeDouble(entry,_Digits);
              sl=NormalizeDouble(sl,_Digits);
              tp=NormalizeDouble(tp,_Digits);
              
              Print("get back slDistance: ",(entry-sl));
              //calculate lots
                double lots;
                if(!CalculateLots(entry-sl,lots)){return;}
              if(profitDay >DailyProfitTarget || profitDay <DailyLossStop)
              {
               Print("Buy cannot Safeguard account");
              }else
                 {
                   trade.Buy(lots,_Symbol,entry,sl,tp," HMAFastSlow Buy");
                 }
             
            }
            if( fastBuffer[2]<fastBuffer[1] && fastBuffer[1] >fastBuffer[0])
            {
              if(cntBuy >0)
                  {
                    if(TpPoint==0)
                      {
                        ClosePosition(true);
                      }
                   
                  }
            }
            
            
             
        }
        if(slowBuffer[1] < slowBuffer[0])
        {
          Print("Down Trend");
          if(cntBuy>0 )
          {
            ClosePosition(true);
          }
          //Detect Sell
          if(cntSell==0 && fastBuffer[2]<fastBuffer[1] && fastBuffer[1] >fastBuffer[0])
            {
              Print("We Sell Now ");
              if(enoughsignal)
                {
                 SendTelegramMessage("HMAFS We SELL Now");
                 TakeScreenshot();
                 SendPhotoToTelegram("chart.png");
                 SendTelegramMessage(AccountInfoString(ACCOUNT_NAME)+" Screenshot captured.");
                }
              double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
              
              double tp=TpPoint==0?0:entry-TpPoint*_Point;
              double sl=SlPoints==0?fastBuffer[0]:entry+SlPoints*_Point;
              
              entry=NormalizeDouble(entry,_Digits);
              tp=NormalizeDouble(tp,_Digits);
              sl=NormalizeDouble(sl,_Digits);
              Print("get back slDistance: ",(sl-entry));
              //calculate lots
             double lots;
             if(!CalculateLots(sl-entry,lots)){return;}
              
              if(profitDay >DailyProfitTarget || profitDay <DailyLossStop)
              {
                Print("Sell No  safegaurd");
              }else
              {
                  trade.Sell(lots,_Symbol,entry,sl,tp," HMAFastSlow Sell");
              }
              
              
            }
            if(fastBuffer[2]>fastBuffer[1] && fastBuffer[1] <fastBuffer[0])
            {
                if(cntSell >0)
                  {
                      if(TpPoint==0)
                        {
                          ClosePosition(false);
                        }
                   
                  }
            }
          
         
            
        }
      
     }
   
  }
   
  void Countpositions(int &cntBuy,int &cntSell)
{
    cntBuy=0;
    cntSell=0;
    
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicNumber)
                {
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ cntBuy++;}
                  if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ cntSell++;}
                }
           }
      }
}

void ClosePosition(int buy_sell)
{
       
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicNumber)
                {
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ continue;}
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ continue;}
                  trade.PositionClose(ticket);
                }
           }
      }
}
//calculate lots

bool CalculateLots(double slDistance, double &lots)
{
  lots=0.0;
  
  if(InpLotMode==LOT_MODE_FIXED)
    {
     lots=InpLots;
    }else
    {
     double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
     double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
     double volumestep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
     
     double riskMoney=InpLotMode==LOT_MODE_MONEY?InpLots:AccountInfoDouble(ACCOUNT_EQUITY)*InpLots*0.01;
     double moneyVolumeStep=(slDistance/tickSize)*tickValue*volumestep;
     
     lots=MathFloor(riskMoney/moneyVolumeStep)*volumestep;
        
    }
    Print("Calculated  lots: ",lots);
    //check calculated lots
    if(!CheckLots(lots)){return false;}
    
  return true;
}


//check lots
bool CheckLots(double &lots)
{
  double min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  
  if(lots<min)
    {
     Print("Lotsize will be set to minimum lot value lots: ",lots);
     lots=min;
    }
    if(lots>max)
    {
     Print("Lotsize will be set to maximum lot value, lots: ",lots);
     lots=max;
    }
    
    lots=(int)MathFloor(lots/step)*step;
    Print("Calculated check lots: ",lots," max | min :",max," ",min);
  return true;
}

void trailing(int buy_sell)
{
    double trailingbuffer[];
    CopyBuffer(handleFastHMA,0,1,4,trailingbuffer);
       
    int total=PositionsTotal()-1;
    
    for(int i=total;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         ulong MagicNo=PositionGetInteger(POSITION_MAGIC);
         double currentSl=PositionGetDouble(POSITION_SL);
         
         if(PositionSelectByTicket(ticket))
           {
              if(MagicNo==InpMagicNumber)
                {
                  if(buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
                       if(currentSl<trailingbuffer[1])
                         {
                          trade.PositionModify(ticket,trailingbuffer[0],0);
                         }
                   }
                  if(!buy_sell && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){ 
                      if(currentSl>trailingbuffer[1])
                         {
                          trade.PositionModify(ticket,trailingbuffer[0],0);
                         }
                  }
                }
           }
      }
}

void UpdateStopLoss(int slDistance)
{
   int total=PositionsTotal();
   for(int i=total-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get Position Ticket"); return;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select the ticket");return;}
      ulong magicnumber=9;
      if(magicnumber!=PositionGetInteger(POSITION_MAGIC)){Print("Failed to get Position Magic Number");return;}
      if(magicnumber==InpMagicNumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get Position Type");return;}
         
         double currentSL,currentTP;
         if(!PositionGetDouble(POSITION_SL,currentSL)){Print("Failed to get current Position Stop Loss");return;}
         if(!PositionGetDouble(POSITION_TP,currentTP)){Print("Failed to get current Position Take Profit");return;}
         
         
         double currentPrice=type==POSITION_TYPE_BUY?SymbolInfoDouble(_Symbol,SYMBOL_BID) :SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         int n = type==POSITION_TYPE_BUY?1:-1;
         double newSL=currentPrice-slDistance*n*_Point;
         if(!NormalizePrice(newSL)){return;}
         
         if((newSL*n)<(currentSL*n) || NormalizeDouble(MathAbs(newSL-currentSL),_Digits)<_Point)
           {
             continue;
           }
         long level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
         if(level!=0 && MathAbs(currentPrice-newSL)<=level*_Point)
           {
            Print("New Stop Loss inside Stop  Level");
            continue;
           } 
         if(!trade.PositionModify(ticket,newSL,currentTP))
           {
             Print("Failed to Modify new Sl ",ticket);
             return;
           }   
        }
     }

}

//Normalize Price Function
bool NormalizePrice(double &price)
{
  double tickSize=0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize))
    {
     Print("Failed to get Tick Size");
     return false;
    }
    price=NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
    return true;
}

int  Authorization()
{
    long AuthuserAccount=2000903183;
    
    long availableAccount=AccountInfoInteger(ACCOUNT_LOGIN);
    // Authorized: 10419166
    Print("Login ",availableAccount," Authorized: ",AuthuserAccount);
    
    if(availableAccount==AuthuserAccount)
      {
        Print("License is valid");
      }else{
        Print("License invalid");
        ExpertRemove();
        return INIT_FAILED;
      }
      
      
    if(TimeCurrent() < StringToTime("2025.03.10"))
      {
        Print("Robot is Valid");
      }else{
        Print("Robot Expired ");
        ExpertRemove();
        return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
     if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
       {
         profitClosed=CalculateDailyProfitClosed();
       }
       
   // 1. Only deal events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong mydeal = trans.deal;
   if(mydeal == 0)
      return;

   // 2. Load history cache
   HistorySelect(TimeCurrent() - (86400 * 30), TimeCurrent());

   // FIX: You MUST select the deal first before calling HistoryDealGetInteger!
   if(!HistoryDealSelect(mydeal))
      return;

   // 3. Only closing deals (Handles complete OUT and partial INOUT closing reversals)
   long entryType = HistoryDealGetInteger(mydeal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT)
      return;

   // 4. Extract Magic Number with Cascading Backups
   long magicNo = HistoryDealGetInteger(mydeal, DEAL_MAGIC);
   
   // Fallback A: Trace the history of the specific position lifecycle to find the opening deal
   if(magicNo == 0 && trans.position > 0)
   {
      if(HistorySelectByPosition(trans.position))
      {
         int totalDeals = HistoryDealsTotal();
         for(int i = 0; i < totalDeals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               magicNo = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               break;
            }
         }
      }
   }
   
   // Fallback B: Look directly at the order ticket that executed this closure
   if(magicNo == 0)
   {
      ulong closeOrderTicket = (ulong)HistoryDealGetInteger(mydeal, DEAL_ORDER);
      if(HistoryOrderSelect(closeOrderTicket))
      {
         magicNo = HistoryOrderGetInteger(closeOrderTicket, ORDER_MAGIC);
      }
   }

   // Fallback C: Scan history for the very first order setup using Position ID
   if(magicNo == 0 && trans.position > 0)
   {
      ulong positionID = trans.position;
      if(HistorySelectByPosition(positionID))
      {
         int totalOrders = HistoryOrdersTotal();
         for(int i = 0; i < totalOrders; i++)
         {
            ulong orderTicket = HistoryOrderGetTicket(i);
            if(HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID) == (long)positionID)
            {
               magicNo = HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);
               if(magicNo != 0) break;
            }
         }
      }
   }
   
   // 5. Execute calculations if the recovered Magic matches your EA input
   Print("Hello Processed Magic: ", magicNo);
   
   if(magicNo == InpMagicNumber)
   {
      Print("ontrade MagicNo: ", magicNo);
      double myprofit = HistoryDealGetDouble(mydeal, DEAL_PROFIT);
      Print("ontrade Profit: ", myprofit);

      // update running state
      running_profit += myprofit;
   
      // update bounds (NO rescan loop)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;
   
      // append new point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
   
      // 1. update peak equity
      if(running_profit > peak_equity)
         peak_equity = running_profit;
     
      // 2. compute drawdown
      double current_dd = peak_equity - running_profit;
     
      // 3. track worst drawdown
      if(current_dd > peak_dd)
         peak_dd = current_dd;
       
      Draw();              // build chart
      ChartRedraw();       // force refresh
         
      Print("Draw again ", running_profit, " profit: ", myprofit);
   }
  }  
  
  
double CalculateDailyProfitClosed()
{
   double profit=0;
   MqlDateTime dt;
   TimeTradeServer(dt);
   dt.hour=0;
   dt.min=0;
   dt.sec=0;
   
   datetime timeDaystart=StructToTime(dt);
   datetime timeNow = TimeTradeServer();
   
   HistorySelect(timeDaystart,timeNow+100);
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
     {
        ulong dealTicket = HistoryDealGetTicket(i);
        //double dealProfit=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
        
        int dealType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealType==DEAL_ENTRY_OUT)
         {
            
         
        
        //Print("Deal Ticket: ", dealTicket," profit: ",dealProfit);
        
       
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double mydealprofit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         int type = (int)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ulong order = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
         double commission= HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         //Print("DealTicket: ", dealTicket,", Order: ", order,", Symbol: ", symbol,", Profit: ", profit,", commission ",commission);
               
            //calculate profit
              profit+=mydealprofit+commission; 
             //Print("Profit: ",DoubleToString(profit+=mydealprofit,2));  
               
            }   
            
         }
   return profit;

}
//2050448727




void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 'D') // press D
      {
         dashboard_visible = !dashboard_visible;

         if(dashboard_visible){
            canvas.Resize(W, H);
            canvas.Erase(ColorToARGB(clrBlack));
            Draw();
         }   
         else{
            canvas.Resize(1, 1); // effectively invisible
         }   
        Print("Toggle: ",dashboard_visible);    
      }
   }
}

void BuildHistory()
{
   // RESET STATE
   running_profit = 0;
   peak_equity = 0;
   peak_dd = 0;
   
   min_profit = 0;
   max_profit = 0;
   
   ArrayFree(cumulative_profit_array);
   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);

      if((int)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      
      ulong magicNo=HistoryDealGetInteger(deal,DEAL_MAGIC);
      
      if(magicNo==InpMagicNumber){
      Print("MagicNo: ",magicNo);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

      running_profit += profit;

      // update bounds (NO rescaling loop later)
      if(running_profit > max_profit) max_profit = running_profit;
      if(running_profit < min_profit) min_profit = running_profit;

      // store point
      int s = ArraySize(cumulative_profit_array);
      ArrayResize(cumulative_profit_array, s + 1);
      cumulative_profit_array[s] = running_profit;
      
      // 1. update peak equity
      if(running_profit > peak_equity)
         peak_equity = running_profit;
      
      // 2. compute drawdown
       double current_dd = peak_equity - running_profit;
      
      // 3. track worst drawdown
      if(current_dd > peak_dd)
         peak_dd = current_dd;  
       }  
   }
}

void Draw()
{
   canvas.Erase(ColorToARGB(clrBlack));

   int n = ArraySize(cumulative_profit_array);

   double graphrange = max_profit - min_profit;
   if(graphrange == 0) graphrange = 1;

   if(n >= 2)
   {
      int prev_x = 0;
      int prev_y = 0;

      for(int i = 0; i < n; i++)
      {
         int x = (int)((double)i / (n - 1) * W);

         double value = cumulative_profit_array[i];

         int y = H - (int)((value - min_profit) / graphrange * (H-20))-20;

         if(i > 0)
            canvas.Line(prev_x, prev_y, x, y, ColorToARGB(clrBlue));

         prev_x = x;
         prev_y = y;
      }
   }

   // ✅ ALWAYS draw text (even if n < 2)
   canvas.FontSet("Consolas", 14);

   string text =
      "Click 'D' to hide/show | PnL: " +
      DoubleToString(running_profit, 2)+" peak_equity: "+DoubleToString(peak_equity,2)+" peak_dd: -"+DoubleToString(peak_dd,2);

   canvas.TextOut(30, 15, text, ColorToARGB(clrWhite));

   canvas.Update(true);
}