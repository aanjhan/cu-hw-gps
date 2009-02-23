#include <stdlib.h>
#include "list.h"

List* List_Insert(List** list, void* contents)
{
    List* end;
    List* node;

    if(list==NULL)return NULL;

    node=(List*)malloc(sizeof(List));
    if(node==NULL)return NULL;
    node->contents=contents;
    node->prev=NULL;
    node->next=NULL;

    if(*list==NULL)
    {
        *list=node;
    }
    else
    {
        end=*list;
        while(end->next!=NULL)end=end->next;
        end->next=node;
        node->prev=end;
    }
    
    return node;
}

List* List_Remove(List* list, List* node, Dealloc dealloc)
{
    List* itr;
    
    if(list==NULL || node==NULL)return NULL;
    //Is the node at the start of the list?
    else if(list==node)
    {
        list=node->next;
    }
    //Is the node actually in the list?
    else
    {
        itr=list->next;
        while(itr!=node && itr!=NULL)itr=itr->next;
        if(itr==NULL)return list;
        node->prev->next=node->next;
    }
    
    if(dealloc!=NULL)dealloc(node->contents);
    free(node);
    return list;
}

void List_Free(List* list, Dealloc dealloc)
{
    if(list==NULL)return;

    while(list->next!=NULL)List_Free(list->next,dealloc);
    if(dealloc!=NULL)dealloc(list->contents);
    free(list);
}

List* List_Search(List* list, void* value, Comparator comp)
{
    while(list!=NULL)
    {
        if(comp(list->contents,value)==0)return list;
        list=list->next;
    }

    return NULL;
}
