#ifndef LIST_H
#define LIST_H

typedef struct basic_List {
    void* contents;
    
    struct basic_List* prev;
    struct basic_List* next;
} List;

typedef int(*Comparator)(void* a, void* b);
typedef void(*Dealloc)(void* contents);

List* List_Insert(List** list, void* contents);
List* List_Remove(List* list, List* node, Dealloc dealloc);
void List_Free(List* list, Dealloc dealloc);

List* List_Search(List* list, void* value, Comparator comp);

#endif
