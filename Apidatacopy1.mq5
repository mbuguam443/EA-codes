//+------------------------------------------------------------------+
//|                                                      Apidata.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade/Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(84634);
   trade.Buy(0.01,NULL,0,0,0,"Come home ");
   //SendHistoricalDeals();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
     
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   
  }
  
void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong ticket = trans.deal;

   if(ticket <= 0)
      return;

   // 🔥 FORCE HISTORY REFRESH
   HistorySelect(TimeCurrent() - 86400 * 30, TimeCurrent());

   if(!HistoryDealSelect(ticket))
   {
      Print("Deal not ready: ", ticket);
      return;
   }

   ulong order = HistoryDealGetInteger(ticket, DEAL_ORDER);
   long magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
   string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

   Print("ORDER=", order, " MAGIC=", magic, " COMMENT=", comment);
}  

void OnTradeTransaction1(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
{
  if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong ticket = trans.deal;

   if(ticket <= 0)
      return;

   // 🔥 FORCE HISTORY REFRESH
   HistorySelect(TimeCurrent() - 86400 * 30, TimeCurrent());

   if(!HistoryDealSelect(ticket))
   {
      Print("Deal not ready: ", ticket);
      return;
   }

   ulong order = HistoryDealGetInteger(ticket, DEAL_ORDER);
   long magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
   string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

   Print("ORDER=", order, " MAGIC=", magic, " COMMENT=", comment);

   // -----------------------------------
   // GET DATA
   // -----------------------------------
   string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);

   double profit  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   double volume  = HistoryDealGetDouble(ticket, DEAL_VOLUME);

   long type      = HistoryDealGetInteger(ticket, DEAL_TYPE);

   datetime time  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   
   
   

   Print("Comment: ",comment);

   if(volume <= 0)
      return;

   // -----------------------------------
   // BUILD SAFE JSON (BATCH FORMAT)
   // -----------------------------------
  string json =
         "{"
         "\"deals\":[{"
         "\"deal_ticket\":" + IntegerToString((long)ticket) + ","
         "\"order_ticket\":" + IntegerToString((long)order) + ","
         "\"symbol\":\"" + symbol + "\","
         "\"profit\":" + DoubleToString(profit, 2) + ","
         "\"volume\":" + DoubleToString(volume, 2) + ","
         "\"type\":" + IntegerToString(type) + ","
         "\"magic\":" + IntegerToString(magic) + ","
         "\"comment\":\"" + comment + "\","
         "\"time\":\"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\""
         "}]"
         "}";

   Print("SENDING CLOSED DEAL:");
   Print(json);

   // -----------------------------------
   // SEND TO SERVER (SAFE CONVERSION)
   // -----------------------------------
   uchar post[];
   int len = StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post, len - 1);

   char result_data[];
   string response_headers;

   string headers =
      "Content-Type: application/json\r\n";

   int res = WebRequest(
      "POST",
      "https://greatjourns.com/saveDealDB.php",
      headers,
      5000,
      post,
      result_data,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest FAILED: ", GetLastError());
      return;
   }

   Print("SERVER RESPONSE: ", CharArrayToString(result_data));
}

void SendHistoricalDeals()
{
   // --------------------------------
   // LOAD HISTORY
   // --------------------------------
   datetime from = D'2025.04.01 00:00';
   datetime to   = TimeCurrent();

   if(!HistorySelect(from, to))
   {
      Print("HistorySelect FAILED");
      return;
   }

   int total = HistoryDealsTotal();

   Print("TOTAL DEALS = ", total);

   if(total <= 0)
      return;

   // --------------------------------
   // BATCH SETTINGS
   // --------------------------------
   int batch_size = 1000;

   // --------------------------------
   // LOOP THROUGH ALL BATCHES
   // --------------------------------
   for(int start = 0; start < total; start += batch_size)
   {
      string json =
         "{"
         "\"deals\":[";

      int count = 0;

      // ----------------------------
      // BUILD CURRENT BATCH
      // ----------------------------
      for(int i = start; i < total && count < batch_size; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);

         if(ticket == 0)
            continue;
         // 🔥 GET ENTRY TYPE (CRITICAL FILTER)
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

         // ONLY CLOSED DEALS
         if(entry != DEAL_ENTRY_OUT)
            continue;
         
        
         double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);

         // skip balance operations
         if(volume <= 0)
            continue;

         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         long type     = HistoryDealGetInteger(ticket, DEAL_TYPE);
         datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         
          long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            ulong order = HistoryDealGetInteger(ticket, DEAL_ORDER);

         string item =
            "{"
            "\"deal_ticket\":" + IntegerToString((long)ticket) + ","
            "\"order_ticket\":" + IntegerToString((long)order) + ","
            "\"symbol\":\"" + symbol + "\","
            "\"profit\":" + DoubleToString(profit, 2) + ","
            "\"volume\":" + DoubleToString(volume, 2) + ","
            "\"type\":" + IntegerToString(type) + ","
            "\"magic\":" + IntegerToString(magic) + ","
            "\"comment\":\"" + comment + "\","
            "\"time\":\"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\""
            "}";

         if(count > 0)
            json += ",";

         json += item;

         count++;
      }

      json += "]}";

      // ----------------------------
      // DEBUG
      // ----------------------------
      Print("SENDING BATCH...");
      Print("START INDEX = ", start);
      Print("COUNT = ", count);

      // if batch empty skip
      if(count == 0)
         continue;

      // ----------------------------
      // SEND TO SERVER
      // ----------------------------
      uchar post[];
      StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);

      char result[];
      string response_headers;

      string headers =
         "Content-Type: application/json\r\n";

      int res = WebRequest(
         "POST",
         "https://greatjourns.com/saveDealDB.php",
         headers,
         5000,
         post,
         result,
         response_headers
      );

      // IMPORTANT:
      // DO NOT RETURN HERE
      if(res == -1)
      {
         Print("WebRequest FAILED: ", GetLastError());
         continue;
      }

      Print("SERVER RESPONSE = ", CharArrayToString(result));

      // small pause between batches
      Sleep(300);
   }

   Print("ALL BATCHES COMPLETED");
}