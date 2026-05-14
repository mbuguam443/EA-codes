//+------------------------------------------------------------------+
//|                                        GetDealHistoricalData.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
  trade.SetExpertMagicNumber(65774);
  trade.Buy(0.01,NULL,0,0,0,"YES MAN");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // 1. Process only when a deal record is added to history
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong ticket = trans.deal;
   if(ticket <= 0)
      return;

   // Force terminal history sync for the past 30 days to avoid empty returns
   HistorySelect(TimeCurrent() - (86400 * 30), TimeCurrent());

   if(!HistoryDealSelect(ticket))
   {
      Print("Deal record not fully synced or ready: ", ticket);
      return;
   }

   long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
   
   // 2. Strict Filter: Process strictly on transaction closing events (OUT or INOUT)
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT)
      return;

   // 3. Resolve real magic number across server-side execution gaps
   long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
   
   // Fallback A: Scan historical position lifecycle for opening deal
   if(magic == 0 && trans.position > 0)
   {
      if(HistorySelectByPosition(trans.position))
      {
         int totalDeals = HistoryDealsTotal();
         for(int i = 0; i < totalDeals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               break;
            }
         }
      }
   }
   
   // Fallback B: Trace directly via closing deal's triggering order ticket
   if(magic == 0)
   {
      ulong closeOrderTicket = (ulong)HistoryDealGetInteger(ticket, DEAL_ORDER);
      if(HistoryOrderSelect(closeOrderTicket))
      {
         magic = HistoryOrderGetInteger(closeOrderTicket, ORDER_MAGIC);
      }
   }

   // Fallback C: Scan history database for earliest order using Position ID
   if(magic == 0 && trans.position > 0)
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
               magic = HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);
               if(magic != 0) break;
            }
         }
      }
   }

   // 4. Extract other relevant payload specifications
   ulong order    = HistoryDealGetInteger(ticket, DEAL_ORDER);
   string symbol  = HistoryDealGetString(ticket, DEAL_SYMBOL);
   double profit  = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   double volume  = HistoryDealGetDouble(ticket, DEAL_VOLUME);
   long type      = HistoryDealGetInteger(ticket, DEAL_TYPE);
   datetime time  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

   // FIX: Active polling loop to extract late-writing comments (SL/TP triggers)
   string comment = "";
   for(int i = 0; i < 10; i++)
     {
      comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      if(comment != "") break; 
      
      Sleep(15); // Short wait loop for async broker write operations
      HistorySelect(TimeCurrent() - (86400 * 30), TimeCurrent()); 
      HistoryDealSelect(ticket);
     }

   if(volume <= 0)
      return;

   // 5. Construct secure, valid JSON payload containing resolved properties
   string json =
         "{"
         "\"deals\":[{"
         "\"deal_ticket\":" + IntegerToString((long)ticket) + ","
         "\"order_ticket\":" + IntegerToString((long)order) + "," // Order Ticket extraction included
         "\"symbol\":\"" + symbol + "\","
         "\"profit\":" + DoubleToString(profit, 2) + ","
         "\"volume\":" + DoubleToString(volume, 2) + ","
         "\"type\":" + IntegerToString(type) + ","
         "\"magic\":" + IntegerToString(magic) + ","                     // Magic number extraction included
         "\"comment\":\"" + comment + "\","                             // Comment string extraction included
         "\"time\":\"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\""
         "}]"
         "}";

   Print("SENDING CLOSED DEAL TO SERVER:");
   Print(json);

   // 6. Convert payload and execute WebRequest transfer
   uchar post[];
   int len = StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post, len - 1); // Truncate trailing null character

   char result_data[];
   string response_headers;
   string headers = "Content-Type: application/json\r\n";

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
      Print("WebRequest FAILED. Error code: ", GetLastError());
      return;
   }

   Print("SERVER RESPONSE: ", CharArrayToString(result_data));
}

