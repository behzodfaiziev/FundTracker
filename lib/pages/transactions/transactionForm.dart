import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fund_tracker/models/category.dart';
import 'package:fund_tracker/models/transaction.dart';
import 'package:fund_tracker/pages/categories/categoriesRegistry.dart';
import 'package:fund_tracker/services/databaseWrapper.dart';
import 'package:fund_tracker/services/sync.dart';
import 'package:fund_tracker/shared/library.dart';
import 'package:fund_tracker/shared/styles.dart';
import 'package:fund_tracker/shared/widgets.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class TransactionForm extends StatefulWidget {
  final Transaction tx;

  TransactionForm(this.tx);

  @override
  _TransactionFormState createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _typeAheadController = TextEditingController();

  DateTime _date;
  bool _isExpense;
  String _payee;
  double _amount;
  String _category;

  bool isLoading = false;

  @override
  void initState() {
    _typeAheadController.text = widget.tx.payee;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final _user = Provider.of<FirebaseUser>(context);
    final isEditMode = widget.tx.tid != null;
    final List<Transaction> _transactions =
        Provider.of<List<Transaction>>(context);
    final List<Category> _categories = Provider.of<List<Category>>(context);
    final List<Category> _enabledCategories = _categories != null
        ? _categories.where((category) => category.enabled).toList()
        : [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Transaction' : 'Add Transaction'),
        actions: isEditMode
            ? <Widget>[
                deleteIcon(
                  context,
                  'transaction',
                  () async => await DatabaseWrapper(_user.uid)
                      .deleteTransactions([widget.tx]),
                  () => SyncService(_user.uid).syncTransactions(),
                ),
              ]
            : null,
      ),
      body: (_enabledCategories != null &&
              _enabledCategories.isNotEmpty &&
              !isLoading)
          ? Container(
              padding: formPadding,
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    SizedBox(height: 20.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        isExpenseSelector(
                          context,
                          _isExpense != null
                              ? !_isExpense
                              : !widget.tx.isExpense,
                          'Income',
                          () => setState(() => _isExpense = false),
                        ),
                        isExpenseSelector(
                          context,
                          _isExpense ?? widget.tx.isExpense,
                          'Expense',
                          () => setState(() => _isExpense = true),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.0),
                    datePicker(
                      context,
                      getDateStr(_date ?? widget.tx.date),
                      '',
                      (date) => setState(() => _date = date),
                      DateTime.now(),
                    ),
                    SizedBox(height: 20.0),
                    TypeAheadFormField(
                      autovalidate: _payee != null,
                      validator: (val) {
                        if (val.isEmpty) {
                          return 'Enter a payee or a note.';
                        } else if (val.length > 30) {
                          return 'Max 30 characters.';
                        }
                        return null;
                      },
                      textFieldConfiguration: TextFieldConfiguration(
                        controller: _typeAheadController,
                        decoration: InputDecoration(
                          labelText: 'Payee',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (val) {
                          setState(() => _payee = val);
                        },
                      ),
                      suggestionsCallback: (query) {
                        if (query == '') {
                          return null;
                        } else {
                          final List<String> suggestions = _transactions
                              .where(
                                (tx) => tx.payee
                                    .toLowerCase()
                                    .startsWith(query.toLowerCase()),
                              )
                              .map((tx) => '${tx.payee}::${tx.category}')
                              .toSet()
                              .toList();
                          if (suggestions.length > 0) {
                            return suggestions;
                          } else {
                            return null;
                          }
                        }
                      },
                      itemBuilder: (context, suggestion) {
                        final List<String> splitSuggestion =
                            suggestion.split('::');
                        final String suggestionPayee = splitSuggestion[0];
                        final String suggestionCategory = splitSuggestion[1];

                        final Map<String, dynamic> category =
                            categoriesRegistry.singleWhere(
                                (cat) => cat['name'] == suggestionCategory);
                        return ListTile(
                          leading: Icon(
                            IconData(
                              category['icon'],
                              fontFamily: 'MaterialIcons',
                            ),
                            color: category['color'],
                          ),
                          title: Text(suggestionPayee),
                          subtitle: Text(suggestionCategory),
                        );
                      },
                      onSuggestionSelected: (suggestion) {
                        final List<String> splitSuggestion =
                            suggestion.split('::');
                        final String suggestionPayee = splitSuggestion[0];
                        final String suggestionCategory = splitSuggestion[1];

                        _typeAheadController.text = suggestionPayee;
                        setState(() {
                          _payee = suggestionPayee;
                          _category = suggestionCategory;
                        });
                      },
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      initialValue: widget.tx.amount != null
                          ? widget.tx.amount.toStringAsFixed(2)
                          : '',
                      autovalidate: _amount != null,
                      validator: (val) {
                        if (val.isEmpty) {
                          return 'Please enter an amount.';
                        }
                        if (val.indexOf('.') > 0 &&
                            val.split('.')[1].length > 2) {
                          return 'At most 2 decimal places allowed.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setState(() => _amount = double.parse(val));
                      },
                    ),
                    SizedBox(height: 20.0),
                    Center(
                      child: DropdownButton<String>(
                        items: _enabledCategories.map((category) {
                              return DropdownMenuItem(
                                value: category.name,
                                child: Row(children: <Widget>[
                                  Icon(
                                    IconData(
                                      category.icon,
                                      fontFamily: 'MaterialIcons',
                                    ),
                                    color: categoriesRegistry.singleWhere(
                                        (cat) =>
                                            cat['name'] ==
                                            category.name)['color'],
                                  ),
                                  SizedBox(width: 10.0),
                                  Text(
                                    category.name,
                                  ),
                                ]),
                              );
                            }).toList() +
                            (_enabledCategories.any((category) =>
                                    widget.tx.category == null ||
                                    category.name == widget.tx.category)
                                ? []
                                : [
                                    DropdownMenuItem(
                                      value: widget.tx.category,
                                      child: Row(children: <Widget>[
                                        Icon(
                                            IconData(
                                              _categories
                                                  .singleWhere((cat) =>
                                                      cat.name ==
                                                      widget.tx.category)
                                                  .icon,
                                              fontFamily: 'MaterialIcons',
                                            ),
                                            color: categoriesRegistry
                                                .singleWhere((cat) =>
                                                    cat['name'] ==
                                                    widget
                                                        .tx.category)['color']),
                                        SizedBox(width: 10.0),
                                        Text(
                                          widget.tx.category,
                                        ),
                                      ]),
                                    )
                                  ]),
                        onChanged: (val) {
                          setState(() => _category = val);
                        },
                        value: _category ??
                            widget.tx.category ??
                            _enabledCategories.first.name,
                        isExpanded: true,
                      ),
                    ),
                    SizedBox(height: 20.0),
                    RaisedButton(
                      color: Theme.of(context).primaryColor,
                      child: Text(
                        isEditMode ? 'Save' : 'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState.validate()) {
                          Transaction tx = Transaction(
                            tid: widget.tx.tid ?? Uuid().v1(),
                            date: _date ?? widget.tx.date,
                            isExpense: _isExpense ?? widget.tx.isExpense,
                            payee: _payee ?? widget.tx.payee,
                            amount: _amount ?? widget.tx.amount,
                            category: _category ??
                                widget.tx.category ??
                                _enabledCategories.first.name,
                            uid: _user.uid,
                          );
                          setState(() => isLoading = true);
                          isEditMode
                              ? await DatabaseWrapper(_user.uid)
                                  .updateTransactions([tx])
                              : await DatabaseWrapper(_user.uid)
                                  .addTransactions([tx]);
                          SyncService(_user.uid).syncTransactions();
                          Navigator.pop(context);
                        }
                      },
                    )
                  ],
                ),
              ),
            )
          : Loader(),
    );
  }
}
