#include "tree_node.h"

TreeNode::~TreeNode()
{
    if(left!=NULL)delete left;
    if(right!=NULL)delete right;
}
