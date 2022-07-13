# scotch-smart-contracts
SCOTCH.SALE Smart Contract


Source Code: `/contracts/`

v1.8:
--

**1. Ограничение на Mass Sell**

Для ограничения количества токенов, которые можно разместить на маркетплейсе в рамках одной транзакции,
введена переменная

`uint public _maxItemsForSale`

При массвом размещении количество токенов сверяется с этим значением:

`require(input.length <= _maxItemsForSale, "Amount of specified items exceeds Maximum Allowed Amount");`

Ограничение можно менять:

` function setMaxItemsForSale(uint maxItemsForSale) public onlyOwner {
_maxItemsForSale = maxItemsForSale;
}`

**2. Функционал бенефициара вынесен в абстрактный контракт ScotchBeneficiary**

В абстрактный контракт вынесен функционал связанный с:
 - определением бенефициара
 - изменением бенефициара
 - отправкой средств с контракта 
 - взыманием платы в нативных токенах

Код и связанные методы были просто перенесены в абстрактный класс без изменений (с учетом смены private на internal).


v1.7:
--

**1. Beneficiary - типизированная структура бенефициара**
 
Вместо простого указания адреса бенефициара (_beneficiary) 
появилась структура бенефициара:

`struct Beneficiary { BeneficiaryMode mode; address payable recipient; }`

в которой указывается "режим бенефициара" и его адрес.

Добавлена возможность указания различных режимов бенефициара:
 - **None** - не отправлять комиссию
 - **Beneficiary** - отправить комиссию на кошелек/адрес (отправить и забыть)
 - **Distributor** - отправить комиссию и исполнить распределение комиссии 
 (на будущее для автоматического распределения кэшбэка партнерам и/или комиссии по microDAO)

**2. PartnerID - идентикифактор партнера**

При совершении покупки есть возможность/требование указывать partnerID - ID партнера, со стороны которого произошла покупка.

Если партнер не задан / не известен: partnerID = 0.

Данный partnerID в дальнейшем может быть зарегистрирован / зафиксирован / задан в другом смарт-контракте. 

**3. WhiteList - белый список покупателей**

При размещении токена на маркете теперь необходимо указывать белый список покупателей - список тех адресов,
которым доступент токен для покупки.

Если whiteList не указан (передан пустой массив), то токен будет доступен любому покупателю.

В момент совершения покупки производится проверка адреса покупателя по белому списку (если список не пуст).

**4. Mass Sell - массовое размещение токенов на маркете**

В целях уменьшения количества итерраций при массовой продаже токенов (например, после SAFT NFT),
появился метод, позволяющий разместить сразу несколько токенов:

`placeMarketItems(MarketItemInput[] memory input) public payable`

в качестве аргумента метода должен передаваться массив входных данных для продажи.

**5. isApprovedForAll - проверка аппрува токенов**

Обновлен функционал проверки аппрува NFT. Если раньше маркетплейс проверял наличие отдельного аппрува по конкретному токену, 
то теперь также делается проверка на аппрув всех токенов.

Такая проверка связана с тем, что при массовом размещении может даваться не отдельные аппрувы на каждый токен, а один аппрув на все токены сразу.
