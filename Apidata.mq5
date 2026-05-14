//+------------------------------------------------------------------+
//|                                                      Apidata.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   SendHistoricalDeals();
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


void SendHistoricalDeals()
{
   // -----------------------------------
   // LOAD HISTORY FROM APRIL 2026
   // -----------------------------------
   datetime from = D'2026.04.01 00:00';
   datetime to   = TimeCurrent();

   if(!HistorySelect(from, to))
   {
      Print("HistorySelect FAILED: ", GetLastError());
      return;
   }

   int total = HistoryDealsTotal();

   Print("TOTAL DEALS FOUND = ", total);

   if(total <= 0)
   {
      Print("NO DEALS FOUND");
      return;
   }

   // -----------------------------------
   // BUILD JSON
   // -----------------------------------
   int batch_limit = 100;
   int count = 0;

   string json =
      "{"
      "\"deals\":[";

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);

      // skip balance/commission entries
      if(volume <= 0)
         continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      long type     = HistoryDealGetInteger(ticket, DEAL_TYPE);
      datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      string item =
         "{"
         "\"deal_ticket\":" + IntegerToString((long)ticket) + ","
         "\"symbol\":\"" + symbol + "\","
         "\"profit\":\"" + DoubleToString(profit, 2) + "\","
         "\"volume\":\"" + DoubleToString(volume, 2) + "\","
         "\"type\":" + IntegerToString(type) + ","
         "\"time\":\"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\""
         "}";

      if(count > 0)
         json += ",";

      json += item;

      count++;

      // safety batch limit
      if(count >= batch_limit)
         break;
   }

   json += "]}";

   Print("VALID DEALS = ", count);
   Print("JSON SIZE = ", StringLen(json));

   // -----------------------------------
   // SEND TO PHP
   // -----------------------------------
   uchar post[];
   StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);

   char result[];
   string response_headers;

   string headers =
      "Content-Type: application/json\r\n";

   int res = WebRequest(
      "POST",
      "https://greatjourns.com/receive_deal.php",
      headers,
      5000,
      post,
      result,
      response_headers
   );

   if(res == -1)
   {
      Print("WebRequest FAILED: ", GetLastError());
      return;
   }

   Print("SERVER RESPONSE = ", CharArrayToString(result));
}