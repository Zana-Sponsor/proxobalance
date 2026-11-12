(function(){
  'use strict';
  if(!/^\/summarytransaction\/[^/]+\/?$/.test(location.pathname))return;
  document.body.classList.add('transaction-summary-active');
  const page=document.getElementById('transactionSummaryPage');
  if(page)page.hidden=false;
})();
